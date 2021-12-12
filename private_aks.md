# Setup a fully Private AKS

These directions sill setup a  Private AKS Cluster

> Note: Has a bug still


```bash
PREFIX="private"         # short unique name, min 5 max 8 letters
LOCATION="centralus"     # Azure Region

RESOURCE_GROUP="${PREFIX}-aks"
NETWORK_GROUP="${RESOURCE_GROUP}-network"

# Create Resource Groups
az group create -n $RESOURCE_GROUP -l $LOCATION
az group create -n $NETWORK_GROUP -l $LOCATION

# Create Networks
HUB_VNET="${NETWORK_GROUP}-hub-vnet"
SPOKE_VNET="${NETWORK_GROUP}-spoke-vnet"
HUB_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
HUB_JUMP_SUBNET_NAME="jumpbox-subnet"
KUBE_VNET_NAME="spoke1-kubevnet"
KUBE_ING_SUBNET_NAME="ing-1-subnet"
KUBE_AGENT_SUBNET_NAME="aks-2-subnet"

az network vnet create -g $NETWORK_GROUP -n $HUB_VNET --address-prefixes 10.0.0.0/22
az network vnet create -g $NETWORK_GROUP -n $SPOKE_VNET --address-prefixes 10.0.4.0/22
az network vnet subnet create -g $NETWORK_GROUP --vnet-name $HUB_VNET -n $HUB_FW_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $NETWORK_GROUP --vnet-name $HUB_VNET -n $HUB_JUMP_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $NETWORK_GROUP --vnet-name $SPOKE_VNET -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $NETWORK_GROUP --vnet-name $SPOKE_VNET -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24


# Create Firewall
FIREWALL="${NETWORK_GROUP}-fw"
az extension add --name azure-firewall  # Ensure Firewall Extension Added

az network public-ip create -g $NETWORK_GROUP -n "${FIREWALL}-ip" --sku Standard
az network firewall create --name $FIREWALL --resource-group $NETWORK_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FIREWALL --name $FIREWALL --public-ip-address "${FIREWALL}-ip" --resource-group $NETWORK_GROUP --vnet-name $HUB_VNET
FW_PRIVATE_IP=$(az network firewall show -g $NETWORK_GROUP -n $FIREWALL --query "ipConfigurations[0].privateIpAddress" -o tsv)

# Create Log Analytics
ANALYTICS="${NETWORK_GROUP}-logs"
az monitor log-analytics workspace create --resource-group $NETWORK_GROUP --workspace-name $ANALYTICS --location $LOCATION


# Setup Firewall Route
SUBSCRIPTION=$(az account show --query id -o tsv)
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION/resourceGroups/$NETWORK_GROUP/providers/Microsoft.Network/virtualNetworks/$SPOKE_VNET/subnets/$KUBE_AGENT_SUBNET_NAME"
az network route-table create -g $NETWORK_GROUP --name "${NETWORK_GROUP}-routetable"
az network route-table route create --resource-group $NETWORK_GROUP --name "${NETWORK_GROUP}-routetable-route" --route-table-name "${NETWORK_GROUP}-routetable" --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION
az network vnet subnet update --route-table "${NETWORK_GROUP}-routetable" --ids $KUBE_AGENT_SUBNET_ID
az network route-table route list --resource-group ${NETWORK_GROUP} --route-table-name "${NETWORK_GROUP}-routetable"

# Setup Firewall Rules
az network firewall network-rule create --firewall-name $FIREWALL --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $NETWORK_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
az network firewall network-rule create --firewall-name $FIREWALL --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "UDP" --resource-group $NETWORK_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
az network firewall network-rule create --firewall-name $FIREWALL --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allow service tags" --protocols "Any" --resource-group $NETWORK_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110
az network firewall application-rule create --firewall-name $FIREWALL --resource-group $NETWORK_GROUP --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 101
az network firewall application-rule create  --firewall-name $FIREWALL --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $NETWORK_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" "snapcraft.io" "api.snapcraft.io" "motd.ubuntu.com"  --priority 102

# Create AKS Managed Identity
IDENTITY="${RESOURCE_GROUP}-identity"
az identity create --name $IDENTITY --resource-group $RESOURCE_GROUP
MSI_RESOURCE_ID=$(az identity show -n $IDENTITY -g $RESOURCE_GROUP -o json | jq -r ".id")
MSI_CLIENT_ID=$(az identity show -n $IDENTITY -g $RESOURCE_GROUP -o json | jq -r ".clientId")
az role assignment create --role "Virtual Machine Contributor" --assignee $MSI_CLIENT_ID -g $NETWORK_GROUP

# Create AKS
AKS="${PREFIX}-aks}"
AKS_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)"
az aks create --resource-group $RESOURCE_GROUP --name $AKS  --node-resource-group "${RESOURCE_GROUP}-worker" \
    --enable-managed-identity --enable-private-cluster \
    --load-balancer-sku standard \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --outbound-type userDefinedRouting \
    --vnet-subnet-id $KUBE_AGENT_SUBNET_ID \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --assign-identity $MSI_RESOURCE_ID \
    --kubernetes-version $AKS_VERSION

```
