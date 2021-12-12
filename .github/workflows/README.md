# Pipeline Instructions

A Service Principal is used as the identity to deploy the resources from the pipelines.

__Create Service Prinicpal__

> Note: Manual-Templates requires a scope of subscription owner.
```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
ACCESS_LEVEL="Owner" ## or "Contributor"
# If contributor
az ad sp create-for-rbac --name "iac-github-actions" \
  --role $ACCESS_LEVEL \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth \
  -ojson
```

__Create Github Secrets__

1. `AZURE_CREDENTIALS`: The Service Principal's json output.

```bash
# Sample Format
{
  "clientId": "00000000-0000-0000-0000-000000000000",                       # Client ID GUID
  "clientSecret": "**********************************",                     # Client Secret
  "subscriptionId": "00000000-0000-0000-0000-000000000000",                 # Subscription ID GUID
  "tenantId": "00000000-0000-0000-0000-000000000000",                       # Tenant ID GUID
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```
