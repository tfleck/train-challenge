
@description('The name of the managed identity to use for the function app.')
param managedIdentityName string

@description('The name of the storage account to use for the function app.')
param storageAccountName string = ''

@description('The name of the blob container to use for the function app deployment.')
param deploymentBlobContainerName string

// ------------------------------------------------
// Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: managedIdentityName
}

// ------------------------------------------------
// Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

// ------------------------------------------------
// Function App


resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'hp-trainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: 'fa-trainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  kind: 'functionapp,linux'
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentBlobContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: managedIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        // valid values are 2048, 4096
        instanceMemoryMB: 2048
        // valid range is [40, 1000]
        maximumInstanceCount: 40
      }
      runtime: { 
        name: 'python'
        version: '3.11'
      }
    }
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storage.name
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedIdentity'
        }
        {
          name: 'AzureWebJobsStorage__clientId'
          value: managedIdentity.properties.clientId
        }
      ]
      minTlsVersion: '1.2'
    }
  }
}


// --------------------------------------------
// Outputs

output functionAppName string = functionApp.name
