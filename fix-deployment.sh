#!/bin/bash

# Quick fix script - Run this to fix your deployment immediately

set -e

RESOURCE_GROUP="production4.0"
APP_NAME="demo-app-33434"
ACR_NAME="nextjsacr"
IMAGE_TAG="v4"

echo "🔧 Fixing Azure App Service deployment..."

# Get ACR password (with quotes to handle special characters)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)

if [ -z "$ACR_PASSWORD" ]; then
    echo "❌ Failed to get ACR password. Enabling admin user..."
    az acr update --name $ACR_NAME --admin-enabled true
    ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
    ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
fi

echo "📦 Building and pushing new image..."
docker build -t ${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG} .
az acr login --name $ACR_NAME
docker push ${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG}

echo "🔐 Setting ACR credentials via app settings (more reliable)..."
# Set password via app settings first (this is more reliable)
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    DOCKER_REGISTRY_SERVER_URL="https://${ACR_NAME}.azurecr.io" \
    DOCKER_REGISTRY_SERVER_USERNAME="$ACR_USERNAME" \
    DOCKER_REGISTRY_SERVER_PASSWORD="$ACR_PASSWORD" \
    DOCKER_CUSTOM_IMAGE_NAME="DOCKER|${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG}" \
    NODE_ENV=production \
    PORT=8080 \
    WEBSITES_PORT=8080 \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false \
    --output none

echo "🔄 Restarting app..."
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP --output none

echo ""
echo "✅ Fix complete! Waiting 15 seconds for app to start..."
sleep 15

echo ""
echo "📊 Checking deployment status..."
echo "Checking if container is running..."
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP 2>&1 | head -30

echo ""
echo "🌐 Your app should be available at:"
echo "   https://${APP_NAME}.azurewebsites.net"
echo ""
echo "💡 If you still see errors, check logs with:"
echo "   az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
