output "public_ip_address" {
  value       = azurerm_public_ip.pip.ip_address
  description = "Địa chỉ IPv4 công khai"
}

output "fqdn_domain" {
  value       = azurerm_public_ip.pip.fqdn
  description = "Tên miền FQDN chính thức của Azure"
}

output "app_url" {
  value       = "http://${azurerm_public_ip.pip.fqdn}"
  description = "Đường dẫn truy cập ứng dụng Web"
}
