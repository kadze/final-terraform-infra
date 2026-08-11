---
description: Tear down today's kadze dev deploy fast and cleanly — de-provision the ALB, delete its Route53 records, terraform destroy the active state, then sweep orphaned CSI EBS volumes. Skips in-cluster teardown (helm uninstalls, namespace/CRD deletes) since destroying the EKS cluster removes all of that automatically.
argument-hint: "[state-key]"
allowed-tools: Bash
---

# destroy-all

Tear down every AWS resource created by today's deploy across the kadze repos
(kadze-platform-tools-25c-ubuntu Helm tools + kadze-versus app + kadze-terraform-infra-25c-ubuntu
Terraform stack), in dependency order, with nothing left dangling — and as fast as possible.

## Core principle

`terraform destroy` deletes the EKS cluster, which wipes every in-cluster object
automatically: Helm releases (cert-manager, external-dns, secrets-store-csi,
eks-monitoring, eks-logging, kadze-versus frontend/backend), namespaces, CRDs — all of it.
**Do not** `helm uninstall`, `kubectl delete namespace`, or `kubectl delete crd` anything
before the destroy. That work is redundant and only slows the teardown down.

Three things live *outside* Terraform's reach and must be cleaned up manually,
before/alongside `terraform destroy`:

1. **The shared ALB** (provisioned by the AWS Load Balancer Controller for the
   `team-gateway` Gateway in the `platform-tools` namespace). If it isn't
   de-provisioned first, its ENIs block subnet/SG/VPC deletion (`DependencyViolation`)
   and can orphan a VPC.
2. **Route53 records** pointing at that ALB (created by `external-dns` for whatever
   HTTPRoutes exist that day — grafana, kibana, the kadze-versus app, any future app).
   Terraform doesn't own these.
3. **EBS volumes dynamically provisioned by the EBS CSI driver** (Prometheus/
   Elasticsearch PVC-backed volumes, etc.). Terraform destroy deletes the nodes and
   cluster out from under them, so they're left behind, unattached, still billing
   ~$0.08-0.10/GB-month with nothing using them.

## Steps

1. **Connect to the cluster**
   ```bash
   aws eks update-kubeconfig --name eks-kadze-dev --region us-east-1
   ```

2. **Capture the ALB DNS name before touching anything** — needed to match Route53
   records even after the LB disappears:
   ```bash
   ALB_DNS=$(kubectl get gateway team-gateway -n platform-tools -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
   ```
   If empty, the Gateway/ALB is already gone — skip straight to step 6.

3. **Delete the Gateway** to trigger ALB de-provisioning:
   ```bash
   kubectl delete -f /Users/andriishevtsov/Documents/claude/final-proj/kadze-platform-tools-25c-ubuntu/gateway/gateway.yaml --ignore-not-found
   ```

4. **Poll for ALB removal** instead of a blind sleep — faster on average and avoids
   racing the VPC destroy:
   ```bash
   for i in $(seq 1 18); do
     STILL_THERE=$(aws elbv2 describe-load-balancers \
       --query "LoadBalancers[?DNSName=='${ALB_DNS%.}'].LoadBalancerArn" --output text 2>/dev/null)
     [ -z "$STILL_THERE" ] && break
     sleep 5
   done
   ```
   Max ~90s; in practice it usually clears in 20-30s.

5. **Delete every Route53 record pointing at `$ALB_DNS`**, never touching the ACM
   validation CNAME:
   ```bash
   HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
     --dns-name shevtsov.click. --query 'HostedZones[0].Id' --output text | cut -d'/' -f3)
   aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" \
     --query "ResourceRecordSets[?contains(ResourceRecords[0].Value, '${ALB_DNS%.}') || contains(AliasTarget.DNSName, '${ALB_DNS%.}')]"
   ```
   Build one batched `change-resource-record-sets` request with an `"Action": "DELETE"`
   entry for every record that matched, and send it in a single call. Skip silently if
   nothing matches. **Never** delete the `_<hash>.shevtsov.click` → `*.acm-validations.aws.`
   record — that's unrelated to platform-tools and must survive every cycle.

6. **Find the live Terraform state.** If `$ARGUMENTS` already names a state key, use it
   directly and skip the lookup. Otherwise:
   ```bash
   aws s3 ls s3://381492277294-state-bucket-dev/feature/ --recursive
   ```
   Pick the key with the most recent `LastModified` and a non-trivial size (an empty/
   already-destroyed state is ~150-200 bytes). State the chosen key to the user in one
   line before proceeding if more than one candidate looks plausible.

7. **Destroy the Terraform stack**, from `kadze-terraform-infra-25c-ubuntu/roots/environments/dev`:
   ```bash
   terraform init -backend-config="bucket=381492277294-state-bucket-dev" -backend-config="key=<chosen-key>" -reconfigure
   terraform destroy -auto-approve -input=false
   ```
   This removes the EKS cluster, node groups, VPC, IAM roles/IRSA modules, security
   groups, endpoints — everything Terraform manages, in correct dependency order,
   automatically.

8. **Sweep orphaned EBS volumes left behind by the EBS CSI driver.** These are dynamically-
   provisioned PVs (Prometheus `prometheus-data`, Elasticsearch `elasticsearch-data`, etc.)
   that Terraform never owned and that outlive the cluster as unattached, still-billing
   volumes. Runs automatically, no confirmation gate — filtered strictly by the
   `kubernetes.io/cluster/eks-kadze-dev: owned` tag plus `available` (unattached) status,
   so it can never touch an unrelated volume (e.g. anything belonging to `reviews-25c-vpc`
   or another cluster):
   ```bash
   ORPHANED_VOLUMES=$(aws ec2 describe-volumes \
     --filters "Name=status,Values=available" "Name=tag:kubernetes.io/cluster/eks-kadze-dev,Values=owned" \
     --query 'Volumes[].VolumeId' --output text)
   for v in $ORPHANED_VOLUMES; do
     aws ec2 delete-volume --volume-id "$v"
   done
   ```
   Report what was deleted (volume IDs + total GB reclaimed) after the fact. If the filter
   matches nothing, skip silently.

9. **One cheap sanity check** — catches the orphaned-VPC failure mode that has
   happened before when the ALB wasn't cleared first:
   ```bash
   aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`false`].{ID:VpcId,CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value|[0]}' --output table
   ```
   If anything shows up, report it and ask before doing any manual VPC-level cleanup
   (endpoints → subnets → route tables → SGs → VPC). Don't auto-delete a leftover VPC.

## What this intentionally skips, and why

- Helm uninstalls of cert-manager / external-dns / secrets-store-csi / eks-monitoring /
  eks-logging / kadze-versus releases — gone with the cluster.
- `kubectl delete namespace` for any namespace — gone with the cluster.
- `kubectl delete crd` for cert-manager / Gateway API CRDs — gone with the cluster.
- Emptying any S3 log bucket before destroy — the log bucket is not Terraform-managed
  (`modules/fluentd-s3-irsa` only creates an IAM role + policy), so `terraform destroy`
  never touches it.

## Confirmation gates

Always show the user the resolved Terraform state key before running `terraform destroy`,
and show the matched Route53 records before deleting them. Both are destructive and not
easily undone — don't run them silently even though everything else in this skill is safe
to execute without asking. The orphaned-EBS sweep (step 8) is the one destructive action
that runs *without* a gate — it's scoped tightly enough by the `kubernetes.io/cluster/
eks-kadze-dev: owned` tag filter that a wrong hit isn't realistically possible; still
report what got deleted afterward so it's never a silent action.
