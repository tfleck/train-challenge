
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
  kind: 'functionapp'
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      minTlsVersion: '1.2'
    }
    httpsOnly: true
    clientAffinityEnabled: false
    clientCertEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output functionAppName string = functionApp.name
