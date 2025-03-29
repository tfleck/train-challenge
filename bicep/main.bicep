@description('The version of Python to use for the function app.')
param pythonVersion string

@description('The client id of the identity that is used to deploy app code.')
@secure()
param deployClientId string

@description('The client id of the github oauth integration.')
@secure()
param githubAuthClientId string

@description('The client secret of the github oauth integration.')
@secure()
param githubAuthClientSecret string

module logging 'logging.bicep' = {
  name: 'logging'
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    deployClientId: deployClientId
  }
}

module functionapp 'function-app.bicep' = {
    name: 'functionapp'
    params: {
        aiConnectionString: logging.outputs.aiConnectionString
        deploymentBlobContainerName: storage.outputs.deploymentBlobContainerName
        pythonVersion: pythonVersion
        storageAccountName: storage.outputs.storageAccountName
        githubAuthClientId: githubAuthClientId
        githubAuthClientSecret: githubAuthClientSecret
    }
}

output functionAppName string = functionapp.outputs.functionAppName
