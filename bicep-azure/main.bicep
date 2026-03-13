@description('The Azure region for the deployment.')
param location string = 'southeastasia' // Singapore region for lowest latency

@description('A unique suffix to prevent naming collisions.')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// 1. Azure Key Vault (IM8 Secrets Management)
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'epiq-kv-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true // Modern Zero-Trust access control
  }
}

// 2. Azure Storage Account (IM8 WORM Vault Foundation)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'epiqworm${uniqueSuffix}' // Must be lowercase and alphanumeric
  location: location
  sku: {
    name: 'Standard_LRS' // Cost-effective for the showcase
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false // Strict IM8 block on public access
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

output keyVaultName string = keyVault.name
output storageAccountName string = storageAccount.name
