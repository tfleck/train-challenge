@description('The name of the function app to use for the backend.')
param functionAppName string

@description('The name of the app insights instance to send logs to.')
param appInsightsName string

resource functionApp 'Microsoft.Web/sites@2024-04-01' existing = {
  name: functionAppName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
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

resource functionApiLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'functionLogger'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    isBuffered: true
    resourceId: functionApp.id
  }
}

resource apimAppInsights 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: functionApiLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: json('100')
    }
    frontend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
  }
}
