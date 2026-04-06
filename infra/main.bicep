targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string

@description('Name of the storage account to create.')
@minLength(3)
@maxLength(24)
@secure()
param storageAccountName string = uniqueString(resourceGroup().id)

@description('SKU for the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageSkuName string = 'Standard_LRS'

@description('Kind of the storage account.')
@allowed([
  'StorageV2'
])
param storageKind string = 'StorageV2'

@description('Enable public network access for the storage account.')
param publicNetworkAccess string = 'Disabled'

@description('Tags to apply to all resources.')
param resourceTags object = {
  environment: 'production'
  project: 'sample-app'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: toLower(storageAccountName)
  location: location
  sku: {
    name: storageSkuName
  }
  kind: storageKind
  tags: resourceTags
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: publicNetworkAccess
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'
    }
    accessTier: 'Hot'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountNameOut string = storageAccount.name
output locationOut string = location