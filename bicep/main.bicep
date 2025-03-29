@description('The version of Python to use for the function app.')
param pythonVersion string

@description('The client id of the identity that is used to deploy app code.')
@secure()
param deployClientId string

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    deployClientId: deployClientId
  }
}

module functionapp 'function-app.bicep' = {
    name: 'functionapp'
    params: {
        storageAccountName: storage.outputs.storageAccountName
        deploymentBlobContainerName: storage.outputs.deploymentBlobContainerName
        pythonVersion: pythonVersion
    }
}

output functionAppName string = functionapp.outputs.functionAppName
