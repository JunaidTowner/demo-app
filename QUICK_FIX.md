# Quick Fix for Azure App Service Deployment

## Problem
You're seeing `ImagePullFailure` errors because Azure App Service can't authenticate with ACR.

## Solution 1: Use the Deployment Script (Easiest)

Run this command:

```bash
./deploy-azure.sh
```

This script will:
1. Get ACR credentials automatically
2. Build and push your Docker image
3. Configure App Service with proper authentication
4. Set all required environment variables
5. Restart the app

## Solution 2: Manual Fix

### Step 1: Get ACR Password
```bash
ACR_PASSWORD=$(az acr credential show --name nextjsacr --query passwords[0].value -o tsv)
echo $ACR_PASSWORD
```

### Step 2: Configure App Service with Password
```bash
az webapp config container set \
  --name demo-app-33434 \
  --resource-group production4.0 \
  --docker-custom-image-name nextjsacr.azurecr.io/nextjs-app:v3 \
  --docker-registry-server-url https://nextjsacr.azurecr.io \
  --docker-registry-server-user nextjsacr \
  --docker-registry-server-password "$ACR_PASSWORD"
```

**Important:** Use quotes around `$ACR_PASSWORD` because it contains special characters!

### Step 3: Set Environment Variables
```bash
az webapp config appsettings set \
  --name demo-app-33434 \
  --resource-group production4.0 \
  --settings \
    NODE_ENV=production \
    PORT=8080 \
    WEBSITES_PORT=8080 \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false
```

### Step 4: Build and Push New Image
```bash
# Build
docker build -t nextjsacr.azurecr.io/nextjs-app:v3 .

# Login
az acr login --name nextjsacr

# Push
docker push nextjsacr.azurecr.io/nextjs-app:v3
```

### Step 5: Restart
```bash
az webapp restart --name demo-app-33434 --resource-group production4.0
```

## Solution 3: Use Managed Identity (Recommended for Production)

### Step 1: Assign Managed Identity to App Service
```bash
az webapp identity assign \
  --name demo-app-33434 \
  --resource-group production4.0
```

### Step 2: Get Principal ID
```bash
PRINCIPAL_ID=$(az webapp identity show \
  --name demo-app-33434 \
  --resource-group production4.0 \
  --query principalId -o tsv)
```

### Step 3: Grant ACR Pull Permission
```bash
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-nextjs/providers/Microsoft.ContainerRegistry/registries/nextjsacr \
  --role AcrPull
```

### Step 4: Configure Container (No Password Needed!)
```bash
az webapp config container set \
  --name demo-app-33434 \
  --resource-group production4.0 \
  --docker-custom-image-name nextjsacr.azurecr.io/nextjs-app:v3 \
  --docker-registry-server-url https://nextjsacr.azurecr.io
```

## Verify Deployment

### Check Logs
```bash
az webapp log tail --name demo-app-33434 --resource-group production4.0
```

### Check Container Status
```bash
az webapp show \
  --name demo-app-33434 \
  --resource-group production4.0 \
  --query "{state:state, defaultHostName:defaultHostName}" -o json
```

### Test the App
Open: `https://demo-app-33434.azurewebsites.net`

## Common Issues

### Issue: ImagePullFailure
**Cause:** ACR authentication failed
**Fix:** Make sure password is set correctly with quotes, or use managed identity

### Issue: Application Error
**Cause:** App not listening on correct port/interface
**Fix:** The Dockerfile now uses standalone mode which handles this automatically

### Issue: Static Files Not Loading
**Cause:** Missing static files in Docker image
**Fix:** The Dockerfile now copies `.next/static` and `public` folders correctly

## What Changed in Dockerfile

1. ✅ Uses standalone build (smaller, faster)
2. ✅ Listens on `0.0.0.0` (required for Azure)
3. ✅ Uses `process.env.PORT` (Azure sets this automatically)
4. ✅ Runs as non-root user (security best practice)
5. ✅ Copies all required files correctly

