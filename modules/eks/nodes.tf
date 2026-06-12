# AL2023 EKS-optimized AMI — look up on deploy day, don't hardcode
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.cluster_name}-nodes-"

  image_id      = data.aws_ssm_parameter.eks_ami.value
  instance_type = "t3.medium"

  iam_instance_profile {
    name = aws_iam_instance_profile.nodes.name
  }

  vpc_security_group_ids = [
    aws_security_group.nodes.id,
    aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
  ]

  # AL2023 nodeadm bootstrap — joins the cluster and configures kubelet
  user_data = base64encode(templatefile("${path.module}/userdata.tpl", {
    cluster_name         = aws_eks_cluster.main.name
    cluster_endpoint     = aws_eks_cluster.main.endpoint
    cluster_ca           = aws_eks_cluster.main.certificate_authority[0].data
    cluster_service_cidr = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv6_cidr
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2          # 2 hops needed for pods to reach IMDS
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "${var.cluster_name}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      component                                   = "platform-tools"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      component = "platform-tools"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodes" {
  name                = "${var.cluster_name}-nodes"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_size
  vpc_zone_identifier = var.private_subnet_ids

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.nodes.id
        version            = "$Latest"
      }

      # t3a.medium as a spot fallback — same class, Graviton pricing
      override { instance_type = "t3.medium" }
      override { instance_type = "t3a.medium" }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "component"
    value               = "platform-tools"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
