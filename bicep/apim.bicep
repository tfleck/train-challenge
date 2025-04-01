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
  name: 'apim-${functionApp.name}'
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
    credentials: {
      header:{
        'x-functions-key': [
          '{{${faApiKey.name}}}'
        ]
      }
    }
    description: 'Function App'
    protocol: 'http'
    resourceId: uri(environment().resourceManager, functionApp.id)
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    url: 'https://${functionApp.properties.defaultHostName}/api' // Or your function app URL
  }
}

resource faApiKey 'Microsoft.ApiManagement/service/properties@2019-01-01' = {
  parent: apim
  name: '${functionApp.name}-key'
  properties: {
    displayName: '${functionApp.name}-key'
    value: listKeys('${functionApp.id}/host/default', '2019-08-01').functionKeys.default
    tags: [
      'key'
      'function'
      'auto'
    ]
    secret: true
  }
}

resource functionApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  name: 'fa-api'
  parent: apim
  properties: {
    path: 'api'
    apiType: 'http'
    displayName: functionApp.name
    subscriptionRequired: true
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    isCurrent: true
  }
}

var apimAllPolicy = loadTextContent('./apim-policies/apim-all-policy.xml')
resource functionAppPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: functionApi
  name: 'policy'
  properties: {
    value: apimAllPolicy
    format: 'xml'
  }
}

resource septaApiOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
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

var apimOpPolicyRaw = loadTextContent('./apim-policies/apim-op-policy.xml')
var apimOpPolicy = replace(apimOpPolicyRaw, '__apiBackendName__', functionBackend.name)
resource septaApiPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: septaApiOperation
  name: 'policy'
  properties: {
    value: apimOpPolicy
    format: 'xml'
  }
}

resource nextSeptaApiOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  name: 'next-septa'
  parent: functionApi
  properties: {
    displayName: 'next_septa'
    method: 'GET'
    urlTemplate: '/next_septa'
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

resource nextSeptaApiPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: nextSeptaApiOperation
  name: 'policy'
  properties: {
    value: apimOpPolicy
    format: 'xml'
  }
}

resource dcmetroApiOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  name: 'nearest-dcmetro'
  parent: functionApi
  properties: {
    displayName: 'nearest_dcmetro'
    method: 'GET'
    urlTemplate: '/nearest_dcmetro'
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

resource dcmetroApiPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: dcmetroApiOperation
  name: 'policy'
  properties: {
    value: apimOpPolicy
    format: 'xml'
  }
}

resource functionApiLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apim
  name: 'ai-trainchallenge'
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

resource apimAppInsightsLogger 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = {
  parent: apimAppInsights
  name: appInsights.name
}


resource functionApiInsights 'Microsoft.ApiManagement/service/apis/diagnostics@2024-06-01-preview' = {
  parent: functionApi
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
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
  }
}

resource functionApiInsightsLogger 'Microsoft.ApiManagement/service/apis/diagnostics/loggers@2018-01-01' = {
  parent: functionApiInsights
  name: appInsights.name
}
