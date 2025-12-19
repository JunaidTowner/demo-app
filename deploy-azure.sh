#!/bin/bash

# Azure Deployment Script for Next.js App Service
# This script fixes the ACR authentication and deploys your app

set -e

# Configuration - Update these values
RESOURCE_GROUP="production4.0"
APP_NAME="demo-app-33434"
ACR_NAME="nextjsacr"
IMAGE_TAG="v3"

echo "🚀 Starting Azure deployment..."

# Step 1: Get ACR credentials
echo "📋 Getting ACR credentials..."
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

if [ -z "$ACR_PASSWORD" ]; then
    echo "❌ Failed to get ACR password. Make sure admin user is enabled."
    exit 1
fi

echo "✅ ACR credentials retrieved"

# Step 2: Build Docker image
echo "🔨 Building Docker image..."
docker build -t ${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG} .

# Step 3: Login to ACR
echo "🔐 Logging into ACR..."
az acr login --name $ACR_NAME

# Step 4: Push image to ACR
echo "📤 Pushing image to ACR..."
docker push ${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG}

# Step 5: Configure App Service container with proper credentials
echo "⚙️  Configuring App Service container..."
az webapp config container set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-custom-image-name ${ACR_NAME}.azurecr.io/nextjs-app:${IMAGE_TAG} \
  --docker-registry-server-url https://${ACR_NAME}.azurecr.io \
  --docker-registry-server-user $ACR_USERNAME \
  --docker-registry-server-password "$ACR_PASSWORD"

# Step 6: Set required environment variables
echo "🔧 Setting environment variables..."
az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    NODE_ENV=production \
    PORT=8080 \
    WEBSITES_PORT=8080 \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false

# Step 7: Restart the app
echo "🔄 Restarting App Service..."
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP

echo "✅ Deployment complete!"
echo "🌐 Your app should be available at: https://${APP_NAME}.azurewebsites.net"
echo ""
echo "📊 To view logs, run:"
echo "   az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"

