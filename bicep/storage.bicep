@description('The client id of the identity that is used to deploy app code.')
@secure()
param deployClientId string

@description('The name of the managed identity to use for the function app.')
param managedIdentityName string

// ------------------------------------------------
// Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: managedIdentityName
}

// ------------------------------------------------
// Storage Account

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: 'satrainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: true
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: false
    isNfsV3Enabled: false
    keyPolicy: {
      keyExpirationPeriodInDays: 7
    }
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
    parent: storageAccount
    name: 'default'
}

resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
    parent: blobService
    name: 'deployments'
    properties: {
        publicAccess: 'None'
    }
}

// ------------------------------------------------
// Role Assignments
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

// Allow access from deployment oidc to storage account using a managed identity
resource storageRoleAssignmentGh 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, storageBlobDataOwnerRole.id, deployClientId)
  scope: storageAccount
  properties: {
    description: 'Allow access from github actions to storage account using a managed identity'
    principalId:deployClientId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRole.id
  }
}

// Allow access from function app to storage account using a managed identity
resource storageRoleAssignmentFa 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, storageBlobDataOwnerRole.id, managedIdentity.id)
  scope: storageAccount
  properties: {
    description: 'Allow access from function app to storage account using a managed identity'
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRole.id
  }
}

// ------------------------------------------------
// Outputs

output storageAccountName string = storageAccount.name
output deploymentBlobContainerName string = deploymentContainer.name
