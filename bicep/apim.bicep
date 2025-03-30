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
    credentials: {
      header:{
        'x-functions-key': functionApp.listKeys().functionKeys.default
      }
    }
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
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    isCurrent: true
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

resource functionAppPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: functionApi
  name: 'policy'
  properties: {
    value: '<!--\r\n    - Policies are applied in the order they appear.\r\n    - Position <base/> inside a section to inherit policies from the outer scope.\r\n    - Comments within policies are not preserved.\r\n-->\r\n<!-- Add policies as children to the <inbound>, <outbound>, <backend>, and <on-error> elements -->\r\n<policies>\r\n  <!-- Throttle, authorize, validate, cache, or transform the requests -->\r\n  <inbound>\r\n    <base />\r\n    <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" allow-private-response-caching="false" must-revalidate="false" downstream-caching-type="none" caching-type="internal">\r\n      <vary-by-query-parameter>latitude</vary-by-query-parameter>\r\n      <vary-by-query-parameter>longitude</vary-by-query-parameter>\r\n    </cache-lookup>\r\n    <rate-limit calls="10" renewal-period="60" />\r\n  </inbound>\r\n  <!-- Control if and how the requests are forwarded to services  -->\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <!-- Customize the responses -->\r\n  <outbound>\r\n    <base />\r\n    <cache-store duration="3600" />\r\n  </outbound>\r\n  <!-- Handle exceptions and customize error responses  -->\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
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
  name: 'ai-trainchallenge'
}
