
@description('The name of the storage account to use for the function app.')
param storageAccountName string = ''

@description('The name of the blob container to use for the function app deployment.')
param deploymentBlobContainerName string

@description('The version of Python to use for the function app.')
param pythonVersion string

@description('The name of the app insights instance to send logs to.')
param appInsightsName string

@description('The client id of the github oauth integration.')
@secure()
param githubAuthClientId string

@description('The client secret of the github oauth integration.')
@secure()
param githubAuthClientSecret string

// ------------------------------------------------
// Application Insights

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}


// ------------------------------------------------
// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
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
    type: 'SystemAssigned'
  }
  kind: 'functionapp,linux'
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${deploymentBlobContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        // valid values are 2048, 4096
        instanceMemoryMB: 2048
        // valid range is [40, 1000]
        maximumInstanceCount: 250
        alwaysReady: [
          {
            instanceCount: 2
            name: 'http'
          }
        ]
      }
      runtime: { 
        name: 'python'
        version: pythonVersion
      }
    }
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'GITHUB_PROVIDER_AUTHENTICATION_SECRET'
          value: githubAuthClientSecret
        }
      ]
      minTlsVersion: '1.2'
    }
  }
}

//Settings for azure app service authentication
resource authsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  properties: {
    globalValidation: {
      requireAuthentication:  false
      unauthenticatedClientAction: 'Return401'
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
    platform: {
      enabled: false
    }
    identityProviders: {
      gitHub: {
        enabled: true
        registration: {
          clientId: githubAuthClientId
          clientSecretSettingName: 'GITHUB_PROVIDER_AUTHENTICATION_SECRET'
        }
      }
    }
  }
}

// ------------------------------------------------
// Role Assignments
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
}

// Allow access from function app to storage account using a managed identity
resource storageRoleAssignmentFa 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, storageBlobDataOwnerRole.id, functionApp.name)
  scope: storageAccount
  properties: {
    description: 'Allow access from function app to storage account using a managed identity'
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRole.id
  }
}


// --------------------------------------------
// Outputs
output functionAppName string = functionApp.name
