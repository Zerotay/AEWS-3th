variable "cluster_name" {
  default = "terraform-eks"
}

variable "kubeconfig_output_path" {
  description = "Where to save the Kubectl config file (if `write_kubeconfig = true`). Assumed to be a directory if the value ends with a forward slash `/`."
  type        = string
  default     = "./"
}

variable "kubeconfig_name" {
  type        = string
  default     = "config"
}

variable "kubeconfig_file_permission" {
  description = "File permission of the Kubectl config file containing cluster configuration saved to `kubeconfig_output_path.`"
  type        = string
  default     = "0600"
}

variable "write_kubeconfig" {
  description = "Whether to write a Kubectl config file containing the cluster configuration. Saved to `kubeconfig_output_path`."
  type        = bool
  default     = true
}


variable "manage_aws_auth" {
  description = "Whether to apply the aws-auth configmap file."
  type        = bool
  default     = true
}
