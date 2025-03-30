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

resource apimPolicy 'Microsoft.ApiManagement/service/policies@2024-06-01-preview' = {
  parent: apim
  name: 'policy'
  properties: {
    value: '<!--\r\n    IMPORTANT:\r\n    - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.\r\n    - Only the <forward-request> policy element can appear within the <backend> section element.\r\n    - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.\r\n    - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.\r\n    - To add a policy position the cursor at the desired insertion point and click on the round button associated with the policy.\r\n    - To remove a policy, delete the corresponding policy statement from the policy document.\r\n    - Policies are applied in the order of their appearance, from the top down.\r\n-->\r\n<policies>\r\n  <inbound></inbound>\r\n  <backend>\r\n    <forward-request />\r\n  </backend>\r\n  <outbound></outbound>\r\n</policies>'
    format: 'xml'
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
    credentials: {
      header:{
        'x-functions-key': [
          '{{${faApiKey.name}}}'
        ]
      }
    }
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

resource functionAppPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: functionApi
  name: 'policy'
  properties: {
    value: '<!--\r\n    - Policies are applied in the order they appear.\r\n    - Position <base/> inside a section to inherit policies from the outer scope.\r\n    - Comments within policies are not preserved.\r\n-->\r\n<!-- Add policies as children to the <inbound>, <outbound>, <backend>, and <on-error> elements -->\r\n<policies>\r\n  <!-- Throttle, authorize, validate, cache, or transform the requests -->\r\n  <inbound>\r\n    <base />\r\n    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" allow-private-response-caching="false" must-revalidate="false" downstream-caching-type="none" caching-type="internal">\r\n      <vary-by-query-parameter>latitude</vary-by-query-parameter>\r\n      <vary-by-query-parameter>longitude</vary-by-query-parameter>\r\n    </cache-lookup>\r\n    <rate-limit calls="10" renewal-period="60" />\r\n  </inbound>\r\n  <!-- Control if and how the requests are forwarded to services  -->\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <!-- Customize the responses -->\r\n  <outbound>\r\n    <base />\r\n    <cache-store duration="3600" />\r\n  </outbound>\r\n  <!-- Handle exceptions and customize error responses  -->\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
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

resource septaApiPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-06-01-preview' = {
  parent: septaApiOperation
  name: 'policy'
  properties: {
    value: '<!--\r\n    - Policies are applied in the order they appear.\r\n    - Position <base/> inside a section to inherit policies from the outer scope.\r\n    - Comments within policies are not preserved.\r\n-->\r\n<!-- Add policies as children to the <inbound>, <outbound>, <backend>, and <on-error> elements -->\r\n<policies>\r\n  <!-- Throttle, authorize, validate, cache, or transform the requests -->\r\n  <inbound>\r\n    <base />\r\n  </inbound>\r\n  <!-- Control if and how the requests are forwarded to services  -->\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <!-- Customize the responses -->\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <!-- Handle exceptions and customize error responses  -->\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
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

resource defaultSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: 'master'
  properties: {
    scope: '${apim.id}/'
    displayName: 'Built-in all-access subscription'
    state: 'active'
    allowTracing: false
  }
}
