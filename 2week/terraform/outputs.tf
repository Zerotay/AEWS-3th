output "endpoint" {
   value = module.eks.cluster_endpoint
}
# output "ssh_key" {
#   value = local_file.private_key
#   sensitive = true
# }
output "operator_ec2_ip" {
  value =  aws_instance.operator.public_ip
  description = "Use this for SSH"
}
output "operator_ec2_id" {
  value =  aws_instance.operator.id
  description = "Use this for SSM"
}
output "ssh_command" {
  value =  "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.operator.public_ip}"
}
output "ssm_command" {
  value =  "aws ssm start-session --target ${aws_instance.operator.id}"
}

resource "local_file" "kubeconfig" {
  content = local.kubeconfig
  filename             = "./kubeconfig"
  directory_permission = "0755"
}

resource "local_file" "private_key" {
  filename = "${path.module}/eks-key.pem"
  content  = tls_private_key.ssh_key.private_key_pem
  file_permission = "0400"
}
# resource "local_file" "publick_key" {
#   filename = "${path.module}/eks.pem"
#   content  = tls_private_key.ssh_key.public_key_pem
#   file_permission = "0400"
# }

