// az sp handled by provisoner
@description('Azure Service Principal')
param azure_service_principal object

@description('Azure Storage Account Data Lake')
param azure_storage_account_data_lake object

@description('Capture settings')
param capture object

@description('Event Hub settings')
param hub object

@description('Massdriver metadata')
param md_metadata object

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: md_metadata.name_prefix
  location: azure_storage_account_data_lake.specs.azure.region
  tags: md_metadata.default_tags
  sku: {
    name: hub.sku
    tier: hub.sku
    capacity: !hub.enable_auto_inflate ? hub.throughput_units : null
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    isAutoInflateEnabled: hub.sku == 'Standard' ? hub.enable_auto_inflate : false
    maximumThroughputUnits: hub.enable_auto_inflate ? hub.throughput_units : null
    zoneRedundant: hub.zone_redundant
    minimumTlsVersion: '1.2'
    disableLocalAuth: true
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: md_metadata.name_prefix
  properties: {
    partitionCount: hub.partition_count
    messageRetentionInDays: hub.message_retention
    captureDescription: {
      enabled: true
      encoding: capture.arvo_encoding
      intervalInSeconds: capture.interval
      sizeLimitInBytes: capture.size_limit * 1024 * 1024
      destination: {
        name: 'EventHubArchive.AzureBlockBlob'
        properties: {
          archiveNameFormat: '{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}'
          blobContainer: '${md_metadata.name_prefix}-eventhub-capture'
          storageAccountResourceId: azure_storage_account_data_lake.data.infrastructure.ari
        }
      }
    }
  }
}

output hub object = {
  data: {
    infrastructure: {
      ari: eventHubNamespace.id
      endpoint: 'sb://${eventHubNamespace.name}.servicebus.windows.net/'
    }
    security: {}
  }
  specs: {
    azure: {
      region: eventHubNamespace.location
    }
  }
}
