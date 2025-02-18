# module "mng_al2023_ondemand_2" {
#   source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

#   name            = "mng_al2023_ondemand_2"
#   cluster_name    = module.eks.cluster_name
#   cluster_version = module.eks.cluster_version

#   subnet_ids = module.eks_vpc.public_subnets_id
#   min_size     = 1
#   max_size     = 5
#   desired_size = 3

#   instance_types = ["t3.medium", "t3.large"]
#   # AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD | AL2023_x86_64_NEURON | AL2023_x86_64_NVIDIA
#   # BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA | CUSTOM 
#   ami_type = "AL2023_x86_64_STANDARD"
#   # ON_DEMAND | SPOT
#   capacity_type  = "SPOT"
#   enable_bootstrap_user_data = true
#   metadata_options = { 
#     "http_endpoint": "enabled", 
#     "http_put_response_hop_limit": 3, 
#     "http_tokens": "required" 
#   }

#   use_custom_launch_template = false
#   disk_size = 20
#   remote_access = {
#     ec2_ssh_key = aws_key_pair.eks_key_pair.key_name
#   }

#   // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
#   // Without it, the security groups of the nodes are empty and thus won't join the cluster.
#   cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
#   vpc_security_group_ids            = [module.eks_vpc.default_sg_id]
#   # vpc_security_group_ids            = [module.eks_vp]

#   taints = {
#     is_spot = {
#       key    = "is_spot"
#       value  = "true"
#       effect = "NO_SCHEDULE"
#     }
#   }
# }

# TODO: Using local block to make nodegroup makes it difficult to set fields, have to find other ways
locals {
  mng_al2023_ondemand = {
    source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

    name            = "al2023_ondemand"
    cluster_name    = module.eks.cluster_name
    cluster_version = module.eks.cluster_version

    subnet_ids = module.eks_vpc.public_subnets_id

    min_size     = 1
    max_size     = 5
    desired_size = 3

    instance_types = ["t3.medium"]
    # AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD | AL2023_x86_64_NEURON | AL2023_x86_64_NVIDIA
    # BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA | CUSTOM 
    ami_type = "AL2023_x86_64_STANDARD"
    # ON_DEMAND | SPOT
    capacity_type  = "ON_DEMAND"
    enable_bootstrap_user_data = true
    pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      dnf install nvme-cli links tree tcpdump sysstat ipvsadm ipset bind-utils htop -y
      for n in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d, -f2- | tr ',' '\n' | sort -un); do echo 0 > /sys/devices/system/cpu/cpu$n/online; done
    EOT
    metadata_options = { 
      "http_endpoint": "enabled", 
      "http_put_response_hop_limit": 2, 
      "http_tokens": "required" 
    }


    use_custom_launch_template = false
    disk_size = 20
    remote_access = {
      ec2_ssh_key = aws_key_pair.eks_key_pair.key_name
    }
  } 

    # bottlerocket = {
    #   ami_type       = "BOTTLEROCKET_x86_64"
    #   instance_types = ["m6i.large"]

    #   min_size = 2
    #   max_size = 4
    #   # This value is ignored after the initial creation
    #   # https://github.com/bryantbiggs/eks-desired-size-hack
    #   desired_size = 2

    #   # This is not required - demonstrates how to pass additional configuration
    #   # Ref https://bottlerocket.dev/en/os/1.19.x/api/settings/
    #   bootstrap_extra_args = <<-EOT
    #     # The admin host container provides SSH access and runs with "superpowers".
    #     # It is disabled by default, but can be disabled explicitly.
    #     [settings.host-containers.admin]
    #     enabled = false

    #     # The control host container provides out-of-band access via SSM.
    #     # It is enabled by default, and can be disabled if you do not expect to use SSM.
    #     # This could leave you with no way to access the API and change settings on an existing node!
    #     [settings.host-containers.control]
    #     enabled = true

    #     # extra args added
    #     [settings.kernel]
    #     lockdown = "integrity"
    #   EOT
    # }
}

# module "mng_al2023_ondemand" {
#   source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

#   name            = "al2024_ondemand"
#   cluster_name    = module.eks.cluster_name
#   cluster_version = module.eks.cluster_version

#   subnet_ids = module.eks_vpc.public_subnets
#   # this value has to be specified if you use this module directly
#   cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
#   vpc_security_group_ids            = [module.eks.node_security_group_id]

#   cluster_service_cidr = module.eks.cluster_service_cidr

#   use_custom_launch_template = false
#   disk_size = 20
#   remote_access = {
#     ec2_ssh_key = aws_key_pair.eks_key_pair.key_name
#   }
#   min_size     = 1
#   max_size     = 5
#   desired_size = 3
#   instance_types = ["t3.medium"]
#   capacity_type  = "ON_DEMAND"
# }


