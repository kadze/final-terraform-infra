# IPv6 Decisions — Story 1.1

**Author:** Andrii Shevtsov  
**Cluster:** `eks-kadze-dev` — `us-east-1`, Kubernetes 1.35  
**Date:** 2026-06-12  

---

## 1. Why IPv6 at all

The CloudFormation cluster ran worker nodes in **public subnets with a public IPv4 address on each node**. That design worked in 2023. It no longer works economically: AWS started billing $0.005/hour per public IPv4 address in February 2024. On a 3-node cluster running continuously that is ~$11/month just for the addresses — before any NAT or data charges. On a 10-node cluster it is ~$36/month. The charge scales with every node you add.

The migration to IPv6-primary eliminates that line item entirely. Nodes get a private IPv4 (for VPC-internal AWS APIs that require it) and a global IPv6 address. All outbound internet traffic leaves over IPv6. No public IPv4, no per-address charge.

---

## 2. Subnet topology

```
VPC: 10.25.0.0/16  +  Amazon-provided /56 IPv6 block
│
├── Public subnets (×3, one per AZ) — dual-stack, LB-only
│     IPv4: 10.25.0.0/19, 10.25.32.0/19, 10.25.64.0/19
│     IPv6: ::/64 slices from the VPC /56
│     → Internet Gateway  (IPv4 + IPv6 ingress/egress)
│     → Used by: ALBs, NLBs (Story 1.3). No worker nodes.
│
└── Private subnets (×3, one per AZ) — dual-stack, nodes-only
      IPv4: 10.25.128.0/19, 10.25.160.0/19, 10.25.192.0/19
      IPv6: ::/64 slices from the VPC /56
      → Egress-Only Internet Gateway  (IPv6 egress only)
      → No public IPv4 on launch (map_public_ip_on_launch = false)
      → Used by: EKS worker nodes, future RDS
```

**Why dual-stack private subnets, not IPv6-only?**  
Two hard constraints prevent pure IPv6 subnets in this VPC:

1. A VPC that has an IPv4 CIDR block (required for AWS-internal services) requires every subnet to also have an IPv4 CIDR. Setting `ipv6_native = true` on a subnet in a dual-stack VPC is rejected by the API.
2. EKS allocates IPv4 ENIs for control-plane communication and cluster networking internals even on an `ip_family = ipv6` cluster. The subnet must have free IPv4 addresses for EKS to create those ENIs.

**What "IPv6-primary" means here:** pod IPs and service IPs are IPv6 (`ip_family = ipv6` in `kubernetesNetworkConfig`). Nodes have a private IPv4 for VPC routing but no public IPv4. The per-node IPv4 charge is eliminated.

---

## 3. EIGW vs NAT Gateway

| | Egress-Only IGW | NAT Gateway |
|---|---|---|
| Traffic | IPv6 only | IPv4 only |
| Hourly cost | $0 | $0.045/hr per AZ |
| Data processing | $0 | $0.045/GB |
| IPv4 reachability | None | Full |
| IPv6 reachability | Full | N/A |

For this cluster the EIGW is the only correct choice: nodes have IPv6 addresses and must reach the internet over IPv6. NAT Gateway handles IPv4 and would be needed for IPv4-only destinations — but we explicitly do not have a NAT Gateway, which means **any IPv4-only internet endpoint is unreachable from pods by design**. See §5 for the reachability gaps this creates.

A NAT Gateway (if we added one) would cost $0.045 × 3 AZs × 720 hours = **$97.20/month** in gateway fees alone, before data transfer. The EIGW costs nothing.

---

## 4. IPv4 cost math

### Before (CloudFormation cluster)

| Item | Rate | Monthly |
|---|---|---|
| 3 nodes × public IPv4 address | $0.005/hr × 3 × 720 | **$10.80** |
| NAT Gateway (nodes were in public subnets — none needed) | — | $0 |
| **Total IPv4 charges** | | **$10.80/month** |

### After (Terraform cluster)

| Item | Rate | Monthly |
|---|---|---|
| Public IPv4 on nodes | Eliminated | **$0** |
| NAT Gateway | Not deployed | **$0** |
| VPC Interface endpoints (ec2, ecr.api, ecr.dkr) | $0.01/hr × 3 endpoints × 3 AZs × 720 | **$64.80** |
| VPC Gateway endpoint (S3) | Free | $0 |
| **Total** | | **$64.80/month** |

### Net vs. CFN cluster: +$54/month

This looks like a cost increase, and on a 3-node dev cluster it is one. The honest framing:

1. **The comparison baseline matters.** If we had migrated to private subnets with a NAT Gateway (the standard pre-IPv6 approach), the endpoint cost ($64.80) is cheaper than NAT ($97.20). The correct comparison for a production-ready private-subnet cluster is IPv6+EIGW+endpoints vs. NAT — and IPv6 wins.

2. **Endpoints are mostly fixed cost.** The per-ENI endpoint charge does not scale with node count. At 10 nodes the NAT approach costs $97.20 + data; the IPv6 approach stays at $64.80. At 20 nodes the savings widen further.

3. **The endpoint list shrinks over time.** As AWS adds IPv6 support to more service endpoints (ECR public has IPv6 in most regions; EC2 API does not yet as of 2026-06-12), VPC endpoints can be removed.

4. **The dev cluster runs intermittently.** If destroyed when not in use (as intended via the destroy workflow), both the node IPv4 charges and the endpoint hourly charges stop. The CFN cluster was always-on.

### What remains that still costs IPv4

- The VPC itself has an IPv4 CIDR — required by AWS for a dual-stack VPC.
- EKS control plane ENIs use private IPv4 addresses from the subnet pool (no charge, these are internal).
- ALBs (Story 1.3) will have public IPv4 addresses (dual-stack ALB). Load balancer IPv4 is a different charge class than EC2 instance IPv4 and is expected.

---

## 5. Reachability gaps

### Gap 1 — EC2 API is IPv4-only (confirmed, mitigated)

`ec2.us-east-1.amazonaws.com` has no AAAA record. Nodes bootstrapping via `nodeadm` call `EC2:DescribeInstances` during startup. Without a path to the EC2 API, nodeadm fails fatally and the node never joins the cluster.

**Mitigation:** VPC Interface endpoint for EC2. Nodes resolve `ec2.us-east-1.amazonaws.com` to the endpoint's private IP inside the VPC and reach it over IPv4 on the VPC-internal network.

**Evidence:** Confirmed by observing `nodeadm` crash logs: `fatal: "CIDR is missing in cluster configuration"` and later (before the fix) repeated DescribeInstances retries with no response. This was the root cause of all DEGRADED addon failures during initial deployment.

### Gap 2 — ECR public endpoints are IPv4-only (confirmed, mitigated)

`*.ecr.aws` (public endpoint) has no AAAA record. Nodes pulling EKS addon container images fail without a reachable ECR endpoint.

**Mitigation:** VPC Interface endpoints for `ecr.api` and `ecr.dkr`. ECR image layers are stored in S3 — the S3 Gateway endpoint handles that leg at no hourly cost.

### Gap 3 — SSM Agent cannot reach SSM service (known gap, not mitigated)

SSM Agent on nodes attempts to connect to `ssm.us-east-1.amazonaws.com` and `ec2messages.us-east-1.amazonaws.com`. These have no AAAA records. SSM-based session access to nodes does not work without adding `ssm`, `ssm-messages`, and `ec2messages` VPC endpoints.

**Current status:** Not added. Adds ~$43/month (3 endpoints × 3 AZs). SSH via a bastion is the fallback for node-level debugging.

**Impact:** No operational impact on cluster function. Only affects the ability to use AWS Systems Manager Session Manager for direct node shell access.

### Gap 4 — IPv4-only pod dependencies (workload-specific, unmitigated by default)

Any pod that calls an IPv4-only external endpoint will fail at runtime. The EIGW carries only IPv6 traffic. There is no automatic fallback.

**Known IPv4-only endpoints teams should audit:**
- Any service without a published AAAA record
- Some older SaaS APIs and webhooks
- Any `nslookup <hostname>` that returns only A records

**Recommended action for each app team:** Before cutover, audit your external dependencies with `dig AAAA <hostname>` for each external API your service calls. If a gap exists, options are: (1) use a dual-stack proxy, (2) request the vendor add IPv6, (3) accept that the service cannot run on this cluster.

### Gap 5 — GHA runners are IPv4-only (confirmed, not a gap)

GitHub Actions runners only have IPv4 addresses. The EKS cluster API endpoint (`endpointPublicAccess = true`) is reachable over IPv4 from GHA because EKS publishes a public IPv4 endpoint regardless of cluster `ip_family`. This was verified — GHA `kubectl` calls work. No action needed.

---

## 6. AWS services confirmed IPv6-capable

| Service | IPv6 support | Notes |
|---|---|---|
| EKS control plane API | IPv4 only (public endpoint) | Reachable from GHA and IPv4 laptops |
| EKS pods/services | IPv6-primary ✓ | `ip_family = ipv6` confirmed working |
| VPC CNI | IPv6 ✓ | Pod IPs confirmed IPv6 in production |
| EC2 instances (nodes) | IPv6 assigned ✓ | Via subnet `assign_ipv6_address_on_creation` |
| ECR (via VPC endpoint) | IPv6 ✓ | Pulls confirmed working after endpoint added |
| S3 (via Gateway endpoint) | IPv6 ✓ | Gateway endpoint has no IPv6 restriction |
| ALB (Story 1.3) | Dual-stack ✓ | Public ALB supports both A and AAAA |
| RDS MySQL 8.0.28+ | Dual-stack ✓ | Verified in AWS docs; needed for Story 3.1 |
| RDS DocumentDB 5.0 | Dual-stack ✓ | Needed for Story 3.3; confirm engine version |
| GitHub (`api.github.com`) | IPv6 ✓ | AAAA record confirmed |

**RDS note for Stories 3.1 / 3.3:** RDS dual-stack mode requires the subnet group to include subnets with IPv6 CIDRs. The private subnets in this VPC are dual-stack, so DB subnet groups can be created from them directly. Confirm the engine versions in use match the minimums above before deploying.

---

## 7. Summary of decisions

| Decision | Choice | Rationale |
|---|---|---|
| Subnet model | Dual-stack (not IPv6-native) | AWS requirement: IPv4 CIDR on all subnets in a dual-stack VPC |
| Outbound from private subnets | EIGW | Eliminates NAT cost ($97/month); IPv6 covers all reachable destinations |
| Pod/service networking | IPv6-primary | Eliminates per-node public IPv4 charge; future-proof |
| VPC endpoints | EC2 + ECR + S3 | Required for nodes to bootstrap without NAT; EC2 API is IPv4-only |
| NAT Gateway | Not deployed | Eliminated by design; any IPv4-only destination is a deliberate gap |
| SSM endpoints | Not deployed | Cost ($43/month) not justified for dev; SSH is the fallback |
