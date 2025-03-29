@description('The version of Python to use for the function app.')
param pythonVersion string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'mi-fa-trainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    managedIdentityName: managedIdentity.name
  }
}

module functionapp 'function-app.bicep' = {
    name: 'functionapp'
    params: {
        managedIdentityName: managedIdentity.name
        storageAccountName: storage.outputs.storageAccountName
        deploymentBlobContainerName: storage.outputs.deploymentBlobContainerName
        pythonVersion: pythonVersion
    }
}

output functionAppName string = functionapp.outputs.functionAppName
