# CI/CD to Azure with GitHub Actions and Bicep

This repository contains a production-grade CI/CD pipeline for deploying Azure infrastructure using Bicep from GitHub Actions.

- CI/CD: GitHub Actions (`.github/workflows/deploy.yml`)
- Cloud provider: Azure
- IaC: Bicep (`infra/main.bicep`)
- Default branch: `main`
- --

## 1. Prerequisites

1. An Azure subscription where you have permission to create:
   - Resource groups
   - Federated credentials on an Azure AD (Entra ID) application (use enviornment entity)(update tokens in secret action and add IAM role of contributer to the application and save)
2. A GitHub repository with this code.
3. `main` branch present (or configure your repo so that `main` is the default branch).

## 2. Files Overview

- `.github/workflows/deploy.yml`  
  GitHub Actions workflow that:
  - Validates the Bicep template on every push/PR to `main`.
  - Deploys to Azure on push to `main` using OIDC (no long-lived secrets).

- `infra/main.bicep`  
  Bicep template that deploys a secure Azure Storage Account into a resource group.

- `README.md`  
  This file, with setup and deployment instructions.

## 3. Azure Setup (OIDC with Federated Credentials) (set secret in action)

The pipeline uses GitHub-Azure OpenID Connect (OIDC) federation. You do **not** store Azure client secrets in GitHub; instead, GitHub presents a short-lived token.

### 3.1 Create an Azure AD Application (Service Principal)

1. Sign in to Azure:

   ```bash
   az login
   az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
   ```

2. Create an app registration and service principal:

   ```bash
   az ad app create \
     --display-name "github-oidc-deploy" \
     --sign-in-audience "AzureADMyOrg" \
     --query "appId" -o tsv
   ```

   Save the returned `appId` as `AZURE_CLIENT_ID`.

3. Create a service principal for the application in your subscription:

   ```bash
   APP_ID="<AZURE_CLIENT_ID_FROM_PREVIOUS_STEP>"
   SUBSCRIPTION_ID="<YOUR_SUBSCRIPTION_ID>"

   az ad sp create --id "$APP_ID"

   az role assignment create \
     --assignee "$APP_ID" \
     --role "Contributor" \
     --scope "/subscriptions/$SUBSCRIPTION_ID"
   ```

4. Get your tenant ID:

   ```bash
   az account show --query tenantId -o tsv
   ```

   Save this as `AZURE_TENANT_ID`.

### 3.2 Configure Federated Credentials for GitHub

1. Go to Azure Portal → Azure Active Directory (Entra ID) → App registrations.
2. Select the `github-oidc-deploy` app.
3. Navigate to **Certificates & secrets** → **Federated credentials** → **Add credential**.
4. Configure the federated credential:
   - **Federated credential scenario**: GitHub Actions deploying Azure resources
   - **Organization**: your GitHub organization/user
   - **Repository**: `owner/repo` of this project
   - **Entity type**: `Branch`
   - **Branch**: `main`
   - **Name**: e.g., `github-main-deploy`

This allows workflows from the `main` branch of your repo to obtain tokens for this application using OIDC.

## 4. GitHub Repository Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions → New repository secret** and add:

- `AZURE_CLIENT_ID` – The appId of the Azure AD application.
- `AZURE_TENANT_ID` – Your Azure tenant ID.
- `AZURE_SUBSCRIPTION_ID` – The subscription ID where you deploy resources.

These are used by `azure/login@v2` in the workflow. No client secret is required because we use OIDC.

## 5. Bicep Template (infra/main.bicep)

The provided Bicep template:

- Target scope: resource group
- Parameters:
  - `location` – Azure region for deployment
  - `storageAccountName` – Storage account name (default is derived from the resource group ID)
  - `storageSkuName` – Storage SKU (default `Standard_LRS`)
  - `storageKind` – Storage kind (default `StorageV2`)
  - `publicNetworkAccess` – Public network access for the storage account (`Disabled` by default)
  - `resourceTags` – Tags applied to resources
- Resources:
  - `Microsoft.Storage/storageAccounts` with secure defaults (HTTPS only, TLS 1.2, blob public access disabled).

You can customize parameters or add additional resources as needed.

## 6. GitHub Actions Workflow (deploy.yml)

### 6.1 Triggers

The workflow is triggered on:

- `push` to `main`
- `pull_request` targeting `main`

### 6.2 Jobs

1. **validate**
   - Checks out the repo.
   - Sets up Azure CLI with Bicep.
   - Builds the Bicep file to ARM JSON.
   - Runs a basic JSON validation using `jq`.

2. **deploy** (depends on `validate`)
   - Runs only on `main` branch (`if: github.ref == 'refs/heads/main'`).
   - Logs in to Azure using OIDC (`azure/login@v2`).
   - Ensures the resource group exists.
   - Builds the Bicep template.
   - Runs `what-if` to preview changes.
   - Executes `az deployment group create` to apply changes.

### 6.3 Environment Variables

Defined in the workflow `env` section:

- `AZURE_LOCATION` – Default deployment region (e.g., `westeurope`).
- `BICEP_FILE` – Path to the Bicep file (`infra/main.bicep`).
- `RESOURCE_GROUP_NAME` – Name of the resource group (e.g., `rg-sample-app-main`).

You can change these values directly in `.github/workflows/deploy.yml`.

## 7. First Deployment

1. Ensure the Azure OIDC setup and GitHub secrets are configured as described.
2. Commit and push the repository to GitHub with the workflow and Bicep files on the `main` branch.
3. Push a change to `main` (or merge a PR into `main`).
4. Go to **Actions** tab in GitHub and monitor:
   - `Validate Bicep` job.
   - `Deploy to Azure` job.

If the workflow completes successfully, you should see:

- A resource group named `rg-sample-app-main` (or your configured name).
- A storage account deployed within that resource group.

## 8. Customization

- **Additional resources**: Extend `infra/main.bicep` with more Azure resources (App Service, SQL, etc.).
- **Multiple environments**: Add more jobs/environments to the workflow (e.g., `dev`, `staging`, `prod`) with separate resource groups and federated credentials.
- **Policy/Compliance**: Integrate additional validation tools (e.g., `bicep linter`, `arm-ttk`, or custom scripts) in the `validate` job.

## 9. Troubleshooting

- **OIDC login fails**:
  - Verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` secrets.
  - Confirm federated credential configuration matches the repo, branch (`main`), and organization.
- **Deployment errors**:
  - Check the `what-if` step logs for detailed error messages.
  - Validate that the storage account name is globally unique if you override it.
- **Permission issues**:
  - Ensure the service principal has `Contributor` (or appropriate) role on the subscription or resource group scope.
