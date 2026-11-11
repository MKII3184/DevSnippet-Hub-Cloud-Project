#!/bin/bash
# ==============================================================================
# DEVSNIPPET HUB - SCRIPT TRIỂN KHAI TỰ ĐỘNG LÊN MICROSOFT AZURE (BASH / CLOUD SHELL)
# ==============================================================================
set -e

RESOURCE_GROUP="rg-devsnippet-eastasia"
LOCATION="eastasia"
RANDOM_ID=$((1000 + RANDOM % 9000))
ACR_NAME="acrdevsnippet${RANDOM_ID}"
APP_ENV_NAME="env-devsnippet"
APP_NAME="app-devsnippet"
IMAGE_TAG="v1.0"
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "devsnippet_super_secret_jwt_token_2026")

echo "=========================================================="
echo "BẮT ĐẦU TRIỂN KHAI DEVSNIPPET HUB LÊN MICROSOFT AZURE"
echo "=========================================================="

# 1. Tạo Resource Group
echo "[1/6] Tạo Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION -o table

# 2. Tạo ACR
echo "[2/6] Tạo Azure Container Registry..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true -o table

ACR_SERVER=$(az acr show --name $ACR_NAME --query "loginServer" -o tsv)
ACR_USER=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASS=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# 3. Build image trên cloud qua ACR Build
echo "[3/6] Build Docker Image qua ACR..."
az acr build --registry $ACR_NAME --image "devsnippet-hub:$IMAGE_TAG" .

# 4. Tạo môi trường Container Apps
echo "[4/6] Khởi tạo Container Apps Environment..."
az containerapp env create --name $APP_ENV_NAME --resource-group $RESOURCE_GROUP --location $LOCATION -o table

# 5. Triển khai Container App
echo "[5/6] Triển khai Container App..."
az containerapp create \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $APP_ENV_NAME \
  --image "$ACR_SERVER/devsnippet-hub:$IMAGE_TAG" \
  --target-port 8080 \
  --ingress external \
  --registry-server $ACR_SERVER \
  --registry-username $ACR_USER \
  --registry-password "$ACR_PASS" \
  --env-vars NODE_ENV=production PORT=8080 JWT_SECRET="$JWT_SECRET" \
  -o table

# 6. Hiển thị URL
APP_URL=$(az containerapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" -o tsv)

echo "=========================================================="
echo "TRIỂN KHAI HOÀN TẤT!"
echo "🌐 URL Công khai: https://$APP_URL"
echo "🩺 Health Check: https://$APP_URL/health"
echo "📊 Metrics:      https://$APP_URL/metrics"
echo "=========================================================="
