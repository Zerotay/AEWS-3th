output "endpoint" {
   value = module.eks.cluster_endpoint
}
output "efs_id" {
  value = aws_efs_file_system.efs.id
}
output "ssh_command" {
  value =  "ssh -i ${local_file.private_key.filename} ec2-user@${aws_instance.operator.public_ip}"
}
output "ssm_command" {
  value =  "aws ssm start-session --target ${aws_instance.operator.id}"
}

resource "local_file" "kubeconfig" {
  content = local.kubeconfig
  filename             = "./config"
  directory_permission = "0755"
}

resource "local_file" "private_key" {
  filename = "${path.module}/eks-key.pem"
  content  = tls_private_key.ssh_key.private_key_pem
  file_permission = "0400"
}

resource "null_resource" "run_local_command" {
  provisioner "local-exec" {
    command = <<-EOT
    cp ~/.kube/config ~/.kube/config.backup
    cp ./config ~/.kube/config
    EOT
  }
  depends_on = [local_file.kubeconfig]
}
