@description('The Azure region for the deployment.')
param location string = 'southeastasia'

@description('A unique suffix to prevent naming collisions.')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// ==========================================
// 1. OBSERVABILITY (Azure Monitor & Sentinel)
// ==========================================
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'epiq-monitor-workspace-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource sentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
  location: location
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'SecurityInsights(${logAnalyticsWorkspace.name})'
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
}

// ==========================================
// 2. NETWORKING (VNet for Private Endpoints)
// ==========================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'epiq-prod-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: '10.1.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ==========================================
// 3. SECURE LANDING ZONE (Key Vault & WORM)
// ==========================================
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
    enableRbacAuthorization: true
  }
}

// Private Endpoint for the Key Vault
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'epiq-kv-private-endpoint'
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'epiqworm${uniqueSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}
