
resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'hostingPlan'
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
