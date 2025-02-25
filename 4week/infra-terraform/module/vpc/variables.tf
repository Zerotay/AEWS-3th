variable "vpc_name" {
  default = "terraform-eks"
  type = string
}

variable "vpc_cidr" {
  default = "192.168.0.0/16"
  type = string
  description = "assumed to cidr block is 16"
}

variable "subnet_count" {
  default = 3
  type = number
  description = "priv + pub pair"
}

variable "azs" {
  default = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
  type = list(string)
  description = "assumed region would be seoul"
}
