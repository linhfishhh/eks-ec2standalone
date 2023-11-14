variable "environment" {
  
}

variable "eks" {
  type = object({
    name = string
    iam_instance_profile = string
    private_subnet_ids = list(string)
    private_subnet_zones = list(string)
    sg_ids = list(string)
    ami_id = string
  })
}
resource "aws_launch_template" "eks_launch_template_ondemand" {
    name = "eks_launch_template_ondemand"
    block_device_mappings {
      device_name = "/dev/xvda"
      ebs {
        delete_on_termination = true
        volume_size = 8
        volume_type = "gp2"
      }
    }

    instance_type = "t2.micro"
    iam_instance_profile {
      name = var.eks.iam_instance_profile
    }

    image_id = var.eks.ami_id

    vpc_security_group_ids = var.eks.sg_ids
    user_data = base64encode(templatefile("${path.module}/userdata.sh", { ClusterName = var.eks.name, AmiId = var.eks.ami_id, GroupName = "eks_launch_template_ondemand" }))
    tags = {
        Environment = var.environment
        "eks:cluster-name" = var.eks.name

    }
}

resource "aws_autoscaling_group" "eks_asg_ondemand" {
    vpc_zone_identifier = [var.eks.private_subnet_ids[0]]
    name = "raichu_asg_eks_ondemand_2cpu_4ram_ap_southeast_1a"
    desired_capacity = 1
    min_size = 1
    max_size = 1

    health_check_grace_period = 15
    health_check_type = "EC2"

    termination_policies = ["OldestLaunchTemplate", "OldestInstance"]

    mixed_instances_policy {
      instances_distribution {
        spot_allocation_strategy = "capacity-optimized"
        on_demand_percentage_above_base_capacity = 0     
      }

      launch_template {

        launch_template_specification {
          launch_template_id = aws_launch_template.eks_launch_template_ondemand.id
          version = "$Latest"
        }
        
        override {
          instance_type = "t2.medium"
          weighted_capacity =  "1"
        }
      }
    }

    lifecycle {
        ignore_changes = [ desired_capacity ]
        create_before_destroy = true
    }

tag {
   key = "eks:cluster-name"
    value = var.eks.name
    propagate_at_launch = true
}
   
  tag {
    key = "k8s.io/cluster-autoscaler/node-template/label/lifecycle"
    value = "Ec2Normal"
    propagate_at_launch = true
  }
  tag {
    key = "k8s.io/cluster-autoscaler/node-template/label/intent"
    value = "apps"
    propagate_at_launch = true
  }
  tag {
    key = "k8s.io/cluster-autoscaler/node-template/label/topology.kubernetes.io/zone"
    value = var.eks.private_subnet_zones[0]
    propagate_at_launch = true
  }
  tag {
    key = "k8s.io/cluster-autoscaler/enabled"
    value = "true"
    propagate_at_launch = true
  }
  tag{
    key = "k8s.io/cluster-autoscaler/${var.eks.name}"
    value = "owned"
    propagate_at_launch = true
  }
  tag{
    key = "kubernetes.io/cluster/${var.eks.name}"
    value = "owned"
    propagate_at_launch = true
  }
}
