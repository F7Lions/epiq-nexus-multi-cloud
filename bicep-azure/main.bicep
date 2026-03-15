@description('The Azure region for the deployment.')
param location string = 'southeastasia'

@description('A unique suffix to prevent naming collisions.')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// ==========================================
// 1. OBSERVABILITY (Log Analytics & Sentinel)
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
// 2. AZURE MONITOR (Metrics & Alerts)
// ==========================================
resource azureMonitorWorkspace 'microsoft.monitor/accounts@2023-04-03' = {
  name: 'epiq-azure-monitor-${uniqueSuffix}'
  location: location
}

// Action Group for alerts - notifies the team
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'epiq-alerts-ag'
  location: 'global'
  properties: {
    groupShortName: 'EpiqAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'Roger-Senior-DevOps'
        emailAddress: 'imraannico@gmail.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Diagnostic Settings - pipe all logs to Log Analytics
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'epiq-diag-settings'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
       
      }
    ]
  }
}

// ==========================================
// 3. NETWORKING (VNet for Private Endpoints)
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
// 4. SECURE LANDING ZONE (Key Vault)
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
    // IM8: Network ACLs - deny all by default
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

// Private Endpoint for Key Vault
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

// Key Vault Diagnostic Settings - pipe to Sentinel
resource kvDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'epiq-kv-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
  }
}

// ==========================================
// 5. WORM STORAGE (Immutable Audit Logs)
// ==========================================
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

// IM8: Blob service required as parent for container
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// IM8: Blob container for immutable audit logs
resource wormContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'audit-logs'
  properties: {
    publicAccess: 'None'
  }
}

// IM8: WORM immutability policy - tamper-proof for 7 days
resource immutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2023-01-01' = {
  parent: wormContainer
  name: 'default'
  properties: {
    immutabilityPeriodSinceCreationInDays: 7
    allowProtectedAppendWrites: false
  }
}

// Storage Diagnostic Settings - pipe to Sentinel
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'epiq-storage-diag'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// ==========================================
// 8. OUTPUTS
// ==========================================
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output storageAccountName string = storageAccount.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

