
// --------------------------------------------------------------------
// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'la-trainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// ------------------------------------------------
// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-trainchallenge'
  location: resourceGroup().location
  tags: resourceGroup().tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    RetentionInDays: 30
    WorkspaceResourceId: logAnalytics.id
  }
}

output appInsightsName string = appInsights.name

