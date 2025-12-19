# Azure App Service Deployment Guide

This guide will help you deploy your Next.js application to Azure App Service using Docker containers.

## Prerequisites

1. **Azure CLI** installed and logged in
2. **Docker** installed locally (for testing)
3. **Azure Container Registry (ACR)** or **Docker Hub** account

## Deployment Options

### Option 1: Deploy via Azure Container Registry (Recommended)

#### Step 1: Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="your-resource-group"
APP_NAME="your-nextjs-app"
LOCATION="eastus"
ACR_NAME="yourregistry$(date +%s)"  # Must be globally unique

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Create App Service Plan (Linux)
az appservice plan create \
  --name "${APP_NAME}-plan" \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku B1

# Create Web App with container
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan "${APP_NAME}-plan" \
  --name $APP_NAME \
  --deployment-container-image-name "${ACR_NAME}.azurecr.io/${APP_NAME}:latest"
```

#### Step 2: Configure ACR Authentication

```bash
# Enable admin user (or use managed identity for production)
az acr update --name $ACR_NAME --admin-enabled true

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

# Configure App Service to use ACR
az webapp config container set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-registry-server-url "https://${ACR_NAME}.azurecr.io" \
  --docker-registry-server-user $ACR_USERNAME \
  --docker-registry-server-password $ACR_PASSWORD \
  --docker-custom-image-name "${ACR_NAME}.azurecr.io/${APP_NAME}:latest"
```

#### Step 3: Build and Push Docker Image

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build and push image
az acr build --registry $ACR_NAME --image ${APP_NAME}:latest .
```

#### Step 4: Restart App Service

```bash
az webapp restart --name $APP_NAME --resource-group $RESOURCE_GROUP
```

### Option 2: Deploy via Docker Hub

#### Step 1: Create App Service

```bash
RESOURCE_GROUP="your-resource-group"
APP_NAME="your-nextjs-app"

# Create App Service Plan
az appservice plan create \
  --name "${APP_NAME}-plan" \
  --resource-group $RESOURCE_GROUP \
  --is-linux \
  --sku B1

# Create Web App
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan "${APP_NAME}-plan" \
  --name $APP_NAME \
  --deployment-container-image-name "your-dockerhub-username/${APP_NAME}:latest"
```

#### Step 2: Build and Push to Docker Hub

```bash
# Build image
docker build -t your-dockerhub-username/${APP_NAME}:latest .

# Push to Docker Hub
docker push your-dockerhub-username/${APP_NAME}:latest
```

#### Step 3: Configure Docker Hub Credentials (if private)

```bash
az webapp config container set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --docker-registry-server-url "https://index.docker.io/v1/" \
  --docker-registry-server-user "your-dockerhub-username" \
  --docker-registry-server-password "your-dockerhub-password" \
  --docker-custom-image-name "your-dockerhub-username/${APP_NAME}:latest"
```

### Option 3: Deploy via GitHub Actions (CI/CD)

Your existing workflow can be updated to build and push Docker images. Here's an enhanced version:

```yaml
name: Build and Deploy to Azure App Service

on:
  push:
    branches: [main]

env:
  AZURE_WEBAPP_NAME: your-app-name
  REGISTRY_NAME: your-acr-name
  IMAGE_NAME: your-app-name

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build and push Docker image
        run: |
          az acr login --name ${{ env.REGISTRY_NAME }}
          az acr build --registry ${{ env.REGISTRY_NAME }} \
            --image ${{ env.IMAGE_NAME }}:${{ github.sha }} .
          az acr build --registry ${{ env.REGISTRY_NAME }} \
            --image ${{ env.IMAGE_NAME }}:latest .
      
      - name: Restart Azure Web App
        run: |
          az webapp restart --name ${{ env.AZURE_WEBAPP_NAME }} \
            --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }}
```

## Important Configuration

### Environment Variables

Set these in Azure Portal or via CLI:

```bash
az webapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --settings \
    NODE_ENV=production \
    PORT=8080
```

**Note:** Azure App Service automatically sets the `PORT` environment variable. Your app should listen on `process.env.PORT` or the default 8080.

### Health Check (Optional but Recommended)

Add a health check endpoint in your Next.js app:

```typescript
// app/api/health/route.ts
export async function GET() {
  return Response.json({ status: 'ok' });
}
```

Then configure in Azure:

```bash
az webapp config set \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --generic-configurations '{"healthCheckPath": "/api/health"}'
```

### Continuous Deployment

Enable continuous deployment from ACR:

```bash
az webapp deployment container config \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-cd true
```

## Testing Locally

Before deploying, test your Docker image locally:

```bash
# Build image
docker build -t nextjs-app:test .

# Run container
docker run -p 8080:8080 nextjs-app:test

# Test in browser
open http://localhost:8080
```

## Troubleshooting

### View Logs

```bash
# Stream logs
az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP

# Download logs
az webapp log download --name $APP_NAME --resource-group $RESOURCE_GROUP
```

### Common Issues

1. **Port binding errors**: Ensure your app listens on `0.0.0.0` and uses `process.env.PORT`
2. **Static files not loading**: Verify `.next/static` and `public` folders are copied correctly
3. **Build failures**: Check that `output: "standalone"` is set in `next.config.ts`

## Cost Optimization

- Use **B1** tier for development/testing (~$13/month)
- Use **S1** or higher for production
- Consider **Azure Container Apps** for serverless container workloads
- Enable **auto-scaling** based on CPU/memory metrics

## Security Best Practices

1. ✅ Dockerfile uses non-root user (already configured)
2. ✅ Multi-stage build reduces image size
3. ✅ Use Azure Key Vault for secrets
4. ✅ Enable HTTPS only in App Service settings
5. ✅ Use managed identity instead of admin credentials when possible

## Next Steps

1. Set up custom domain
2. Configure SSL certificates
3. Set up Application Insights for monitoring
4. Configure backup and disaster recovery

