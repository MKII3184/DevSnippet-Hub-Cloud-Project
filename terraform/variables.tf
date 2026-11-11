variable "resource_group_name" {
  type        = string
  default     = "rg-devsnippet-korea"
  description = "Tên Resource Group trong Azure"
}

variable "location" {
  type        = string
  default     = "koreacentral"
  description = "Region triển khai (Korea Central - Seoul)"
}

variable "domain_name_label" {
  type        = string
  default     = "devsnippet-app-24110903"
  description = "DNS label cho domain cloudapp.azure.com"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s_v2"
  description = "Cấu hình phần cứng VM (2 vCPU, 4GB RAM)"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Đường dẫn file SSH public key"
}
