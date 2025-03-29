
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
  kind: 'functionapp,linux'
  properties: {
    clientAffinityEnabled: false
    clientCertEnabled: false
    functionAppConfig: {
      scaleAndConcurrency: {
        // valid values are 512, 2048, 4096
        instanceMemoryMB: 512
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
      minTlsVersion: '1.2'
    }
  }
}


// --------------------------------------------
// Outputs

output functionAppName string = functionApp.name
