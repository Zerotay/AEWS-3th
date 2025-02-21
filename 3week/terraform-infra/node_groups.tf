module "mng_al2023_ondemand" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  name            = "mng_al2023_ondemand"
  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version
  subnet_ids = module.eks_vpc.public_subnets_id
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_vpc.default_sg_id]
  cluster_service_cidr = module.eks.cluster_service_cidr

  min_size     = 1
  max_size     = 5
  desired_size = 3
  instance_types = ["t3.medium", "t3.large"]
  # AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD | AL2023_x86_64_NEURON | AL2023_x86_64_NVIDIA
  # BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA | CUSTOM 
  ami_type = "AL2023_x86_64_STANDARD"
  # ON_DEMAND | SPOT
  capacity_type  = "ON_DEMAND"
  metadata_options = { 
    "http_endpoint": "enabled", 
    "http_put_response_hop_limit": 3, 
    "http_tokens": "required" 
  }
  disk_size = 100

  enable_bootstrap_user_data = false
  use_custom_launch_template = false
  remote_access = {
    ec2_ssh_key = aws_key_pair.eks_key_pair.key_name
  }
  # taints = {
  #   is_spot = {
  #     key    = "is_spot"
  #     value  = "true"
  #     effect = "NO_SCHEDULE"
  #   }
  # }
}

module "mng_instance_store" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  name            = "mng_instance_store"
  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version
  subnet_ids = module.eks_vpc.public_subnets_id
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_vpc.default_sg_id]
  cluster_service_cidr = module.eks.cluster_service_cidr

  min_size     = 1
  max_size     = 1
  desired_size = 1
  instance_types = ["c5d.large"]
  # AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | AL2023_x86_64_STANDARD | AL2023_ARM_64_STANDARD | AL2023_x86_64_NEURON | AL2023_x86_64_NVIDIA
  # BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64 | BOTTLEROCKET_ARM_64_NVIDIA | BOTTLEROCKET_x86_64_NVIDIA | CUSTOM 
  ami_type = "AL2023_x86_64_STANDARD"
  # ON_DEMAND | SPOT
  capacity_type  = "ON_DEMAND"
  metadata_options = { 
    "http_endpoint": "enabled", 
    "http_put_response_hop_limit": 2, 
    "http_tokens": "required" 
  }

  use_custom_launch_template = true
  # remote_access = {
  #   ec2_ssh_key = aws_key_pair.eks_key_pair.key_name
  # }
  # disk_size = 100

  enable_bootstrap_user_data = false
  # pre_bootstrap_user_data = <<-EOT
  #   #!/bin/bash
  #   echo eseses
  #   yum install nvme-cli links tree tcpdump sysstat ipvsadm ipset bind-utils htop -y
  #   mkfs -t xfs /dev/nvme1n1
  #   systemctl stop containerd
  #   mount /dev/nvme1n1 /run/containerd
  #   systemctl start containerd
  #   echo /dev/nvme1n1 /run/containerd xfs defaults,noatime 0 2 >> /etc/fstab
  # EOT
  cloudinit_pre_nodeadm = [
    {
      content_type = "multipart/mixed; boundary=\"BOUNDARY\""
      content      = <<-EOT
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="BOUNDARY"

        --BOUNDARY
        Content-Type: text/cloud-config

        #cloud-config
        ssh_authorized_keys:
          - ${aws_key_pair.eks_key_pair.public_key}

        --BOUNDARY
        Content-Type: text/x-shellscript

        #!/bin/bash
        yum install nvme-cli links tree tcpdump sysstat ipvsadm ipset bind-utils htop -y
        mkfs -t xfs /dev/nvme1n1
        systemctl stop containerd
        # rm -rf /run/containerd/*
        # mkdir -p /run/containerd
        # mount /dev/nvme1n1 /run/containerd
        # echo "/dev/nvme1n1 /run/containerd xfs defaults,noatime 0 2" >> /etc/fstab
        rm -rf /var/lib/containerd/*
        mkdir -p /var/lib/containerd
        mount /dev/nvme1n1 /var/lib/containerd
        echo "/dev/nvme1n1 /var/lib/containerd xfs defaults,noatime 0 2" >> /etc/fstab
        systemctl start containerd

        --BOUNDARY--
      EOT
    },
    # {
    #   content_type = "text/x-shellscript"
    #   content      = <<-EOT
    #     #!/bin/bash
    #     yum install nvme-cli links tree tcpdump sysstat ipvsadm ipset bind-utils htop -y
    #     echo testest
    #     mkfs -t xfs /dev/nvme1n1
    #     systemctl stop containerd
    #     rm -rf /run/containerd/*
    #     mount /dev/nvme1n1 /run/containerd
    #     systemctl start containerd
    #     echo /dev/nvme1n1 /run/containerd xfs defaults,noatime 0 2 >> /etc/fstab
    #     # # Mount the containerd directories to the 2nd volume
    #     # SECOND_VOL=$(lsblk -o NAME,SERIAL -d |awk -v id="$${VOLUME_ID}" '$2 ~ id {print $1}')
    #     # systemctl stop containerd
    #     # mkfs -t ext4 /dev/$${SECOND_VOL}
    #     # rm -rf /var/lib/containerd/*
    #     # rm -rf /run/containerd/*

    #     # mount /dev/$${SECOND_VOL} /var/lib/containerd/
    #     # mount /dev/$${SECOND_VOL} /run/containerd/
    #     # systemctl start containerd
    #     mkdir -p /home/ec2-user/.ssh
    #     echo "${aws_key_pair.eks_key_pair.public_key}" >> /home/ec2-user/.ssh/authorized_keys
    #     chown -R ec2-user:ec2-user /home/ec2-user/.ssh
    #     chmod 700 /home/ec2-user/.ssh
    #     chmod 600 /home/ec2-user/.ssh/authorized_keys
    #   EOT
    # }
  ]

  labels = {
    disk = "instance_store"
  }
  # taints = {
  #   is_spot = {
  #     key    = "is_spot"
  #     value  = "true"
  #     effect = "NO_SCHEDULE"
  #   }
  # }
}
output "test" {
  value = aws_key_pair.eks_key_pair.public_key
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


