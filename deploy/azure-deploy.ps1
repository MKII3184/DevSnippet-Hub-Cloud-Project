# ==============================================================================
# DEVSNIPPET HUB - SCRIPT TRIỂN KHAI TỰ ĐỘNG LÊN MICROSOFT AZURE
# ==============================================================================
# Hướng dẫn chạy:
# 1. Đảm bảo đã đăng nhập Azure CLI: az login
# 2. Chạy file này: .\deploy\azure-deploy.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = "rg-devsnippet-eastasia"
$LOCATION = "eastasia" # Hong Kong (Độ trễ thấp nhất tới Việt Nam ~30-40ms)
$ACR_NAME = "acrdevsnippet" + (Get-Random -Minimum 1000 -Maximum 9999)
$APP_ENV_NAME = "env-devsnippet"
$APP_NAME = "app-devsnippet"
$IMAGE_TAG = "v1.0"
$JWT_SECRET = [System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "BẮT ĐẦU QUY TRÌNH TRIỂN KHAI DEVSNIPPET HUB LÊN AZURE" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Tạo Resource Group
Write-Host "`n[1/6] Đang tạo Resource Group: $RESOURCE_GROUP tại $LOCATION..." -ForegroundColor Yellow
az group create --name $RESOURCE_GROUP --location $LOCATION --output table

# 2. Tạo Azure Container Registry (ACR) để lưu trữ Docker image
Write-Host "`n[2/6] Đang tạo Azure Container Registry: $ACR_NAME (SKU Basic)..." -ForegroundColor Yellow
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true --output table

$ACR_SERVER = az acr show --name $ACR_NAME --query "loginServer" --output tsv
$ACR_USER = az acr credential show --name $ACR_NAME --query "username" --output tsv
$ACR_PASS = az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv

# 3. Build Docker Image trực tiếp trên Cloud bằng ACR Build (Không cần cài Docker ở máy cá nhân)
Write-Host "`n[3/6] Đang build Docker Image trên Cloud bằng Azure ACR Build..." -ForegroundColor Yellow
az acr build --registry $ACR_NAME --image "devsnippet-hub:$IMAGE_TAG" .

# 4. Tạo Azure Container Apps Environment
Write-Host "`n[4/6] Đang khởi tạo môi trường Azure Container Apps..." -ForegroundColor Yellow
az containerapp env create --name $APP_ENV_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --output table

# 5. Triển khai ứng dụng lên Container Apps với HTTPS và Ingress công khai
Write-Host "`n[5/6] Đang triển khai Container App và cấu hình biến môi trường..." -ForegroundColor Yellow
az containerapp create `
  --name $APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --environment $APP_ENV_NAME `
  --image "$ACR_SERVER/devsnippet-hub:$IMAGE_TAG" `
  --target-port 8080 `
  --ingress external `
  --registry-server $ACR_SERVER `
  --registry-username $ACR_USER `
  --registry-password $ACR_PASS `
  --env-vars NODE_ENV=production PORT=8080 JWT_SECRET=$JWT_SECRET `
  --output table

# 6. Lấy FQDN / URL công khai
$APP_URL = az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" --output tsv

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "TRIỂN KHAI THÀNH CÔNG!" -ForegroundColor Green
Write-Host "🌐 URL Ứng dụng công khai: https://$APP_URL" -ForegroundColor Green
Write-Host "🩺 Health check URL:      https://$APP_URL/health" -ForegroundColor Green
Write-Host "📊 Metrics URL:           https://$APP_URL/metrics" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
