@description('The name of the function app to use for the backend.')
param functionAppName string

resource functionApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: functionAppName
}

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: 'apim-trainchallenge'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    publisherEmail: 'emailtfleck@gmail.com'
    publisherName: 'Theo Fleck'
  }
  sku: {
    name: 'Consumption'
    capacity: 0
  }
}

resource functionBackend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  name: 'fa-backend'
  parent: apim
  properties: {
    protocol: 'http'
    description: 'Function App'
    url: 'https://${functionApp.properties.defaultHostName}/api' // Or your function app URL
    resourceId: uri(environment().resourceManager, functionApp.id)
  }
}

resource functionApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'fa-api'
  parent: apim
  properties: {
    path: 'api'
    apiType: 'http'
    displayName: functionApp.name
    subscriptionRequired: false // Or true, depending on your needs
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${functionApp.properties.defaultHostName}'
  }
}

resource functionApiOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  name: 'nearest-septa'
  parent: functionApi
  properties: {
    displayName: 'nearest_septa'
    method: 'GET'
    urlTemplate: '/nearest_septa'
    request:{
      queryParameters: [
        {
          name: 'latitude'
          required: true
          type: 'number'
        }
        {
          name: 'longitude'
          required: true
          type: 'number'
        }
      ]
    }
  }
}
