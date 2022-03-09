#!/bin/bash

# script name: aci-flp-labs.sh
# Version v0.0.2 20220204
# Set of tools to deploy ACI troubleshooting labs

# "-l|--lab" Lab scenario to deploy
# "-r|--region" region to deploy the resources
# "-u|--user" User alias to add on the lab name
# "-h|--help" help info
# "--version" print version

# read the options
TEMP=`getopt -o g:n:l:r:u:hv --long resource-group:,name:,lab:,region:,user:,help,validate,version -n 'aci-flp-labs.sh' -- "$@"`
eval set -- "$TEMP"

# set an initial value for the flags
RESOURCE_GROUP=""
ACI_NAME=""
LAB_SCENARIO=""
USER_ALIAS=""
LOCATION="uksouth"
VALIDATE=0
HELP=0
VERSION=0

while true ;
do
    case "$1" in
        -h|--help) HELP=1; shift;;
        -g|--resource-group) case "$2" in
            "") shift 2;;
            *) RESOURCE_GROUP="$2"; shift 2;;
            esac;;
        -n|--name) case "$2" in
            "") shift 2;;
            *) ACI_NAME="$2"; shift 2;;
            esac;;
        -l|--lab) case "$2" in
            "") shift 2;;
            *) LAB_SCENARIO="$2"; shift 2;;
            esac;;
        -r|--region) case "$2" in
            "") shift 2;;
            *) LOCATION="$2"; shift 2;;
            esac;;
        -u|--user) case "$2" in
            "") shift 2;;
            *) USER_ALIAS="$2"; shift 2;;
            esac;;    
        -v|--validate) VALIDATE=1; shift;;
        --version) VERSION=1; shift;;
        --) shift ; break ;;
        *) echo -e "Error: invalid argument\n" ; exit 3 ;;
    esac
done

# Variable definition
SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
SCRIPT_NAME="$(echo $0 | sed 's|\.\/||g')"
SCRIPT_VERSION="Version v0.0.2 20220204"

# Funtion definition

# az login check
function az_login_check () {
    if $(az account list 2>&1 | grep -q 'az login')
    then
        echo -e "\n--> Warning: You have to login first with the 'az login' command before you can run this lab tool\n"
        az login -o table
    fi
}

# check resource group and aci
function check_resourcegroup_cluster () {
    RESOURCE_GROUP="$1"
    ACI_NAME="$2"

    RG_EXIST=$(az group show -g $RESOURCE_GROUP &>/dev/null; echo $?)
    if [ $RG_EXIST -ne 0 ]
    then
        echo -e "\n--> Creating resource group ${RESOURCE_GROUP}...\n"
        az group create --name $RESOURCE_GROUP --location $LOCATION -o table &>/dev/null
    else
        echo -e "\nResource group $RESOURCE_GROUP already exists...\n"
    fi

    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -eq 0 ]
    then
        echo -e "\n--> Container instance $ACI_NAME already exists...\n"
        echo -e "Please remove that one before you can proceed with the lab.\n"
        exit 5
    fi
}

# validate ACI exists
function validate_aci_exists () {
    RESOURCE_GROUP="$1"
    ACI_NAME="$2"

    ACI_EXIST=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_EXIST -ne 0 ]
    then
        echo -e "\n--> ERROR: Failed to create container instance $ACI_NAME in resource group $RESOURCE_GROUP ...\n"
        exit 5
    fi
}

# Usage text
function print_usage_text () {
    NAME_EXEC="aci-flp-labs"
    echo -e "$NAME_EXEC usage: $NAME_EXEC -l <LAB#> -u <USER_ALIAS> [-v|--validate] [-r|--region] [-h|--help] [--version]\n"
    echo -e "\nHere is the list of current labs available:\n
*************************************************************************************
*\t 1. ACI deployment on existing resource group fails
*\t 2. ACI deployed with wrong image
*\t 3. 
*************************************************************************************\n"
}

# Lab scenario 1
function lab_scenario_1 () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    check_resourcegroup_cluster $RESOURCE_GROUP $ACI_NAME

    echo -e "\n--> Deploying resources for lab${LAB_SCENARIO}...\n"

    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --vnet aci-vnet-lab200aci \
    --vnet-address-prefix 10.0.0.0/16 \
    --subnet aci-subnet-lab200aci \
    --subnet-address-prefix 10.0.0.0/24 \
    -o table

    validate_aci_exists $RESOURCE_GROUP $ACI_NAME
    
    SUBNET_ID=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query subnetIds[].id -o tsv)

cat <<EOF > aci.yaml
apiVersion: '2021-07-01'
location: $LOCATION
name: appcontaineryaml
properties:
  containers:
  - name: appcontaineryaml
    properties:
      image: mcr.microsoft.com/azuredocs/aci-helloworld
      ports:
      - port: 80
        protocol: TCP
      resources:
        requests:
          cpu: 1.0
          memoryInGB: 1.5
  ipAddress:
    type: Public
    ports:
    - protocol: tcp
      port: '80'
  osType: Linux
  restartPolicy: Always
  subnetIds:
    - id: $SUBNET_ID
      name: default
tags: null
type: Microsoft.ContainerInstance/containerGroups
EOF

    ERROR_MESSAGE="$(az container create --resource-group $RESOURCE_GROUP --file aci.yaml 2>&1)"
    
    echo -e "\n\n************************************************************************\n"
    echo -e "\n--> Issue description: \n Customer has an ACI alredy deployed in the resource group $RESOURCE_GROUP and he wants to deploy another one in the same resource group using the following:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    echo -e "Cx is getting the error message:"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "$ERROR_MESSAGE"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to deploy the second container instance \"appcontaineryaml\"\n"
    echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
    echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
}

function lab_scenario_1_validation () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    ACI_STATUS=$(az container show -g $RESOURCE_GROUP -n appcontaineryaml &>/dev/null; echo $?)
    if [ $ACI_STATUS -eq 0 ]
    then
        echo -e "\n\n========================================================"
        echo -e '\nContainer instance "appcontaineryaml" looks good now!\n'
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "The yaml file aci.yaml is in your current path, you have to modified it in order to be able to deploy the second container instance \"appcontaineryaml\"\n"
        echo -e "Once you find the issue, update the aci.yaml file and run the commnad:"
        echo -e "az container create --resource-group $RESOURCE_GROUP --file aci.yaml\n"
    fi
}

# Lab scenario 2
function lab_scenario_2 () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    check_resourcegroup_cluster $RESOURCE_GROUP $ACI_NAME

    echo -e "\n--> Deploying cluster for lab${LAB_SCENARIO}...\n"
    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image alpine \
    --ports 80 \
    -o table &>/dev/null

    validate_aci_exists $RESOURCE_GROUP $ACI_NAME
    ACI_URI=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query id -o tsv 2>/dev/null)
    
    echo -e "\n\n********************************************************"
    echo -e "\n--> Issue description: \nAn ACI has been deployed with name $ACI_NAME in the resourece group $RESOURCE_GROUP, and it keeps restarting."
    echo -e "Looks like it was deployed with the wrong image."
    echo -e "You have to update the ACI to change the image to nginx.\n"
    echo -e "ACI URI=${ACI_URI}\n"
}

function lab_scenario_2_validation () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    ACI_IMAGE="$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query containers[].image -o tsv)"
    RESTART_COUNT="$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query containers[].instanceView.restartCount -o tsv)"
    ACI_STATUS=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME &>/dev/null; echo $?)
    if [ $ACI_STATUS -eq 0 ] && [[ "$ACI_IMAGE" == "nginx"* ]] && [ $RESTART_COUNT -eq 0 ]
    then
        echo -e "\n\n========================================================"
        echo -e "\nContainer instance \"${ACI_NAME}\" looks good now!\n"
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
    fi
}

# Lab scenario 3
function lab_scenario_3 () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    check_resourcegroup_cluster $RESOURCE_GROUP $ACI_NAME

    echo -e "\n--> Deploying resources for lab${LAB_SCENARIO}...\n"

    az container create \
    --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP \
    --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --ip-address Public \
    --ports 8080 \
    -o table &>/dev/null 



    validate_aci_exists $RESOURCE_GROUP $ACI_NAME
    
    PUBLIC_IP=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query ipAddress.ip -o tsv 2>/dev/null)
    PORT=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query ipAddress.ports[].port -o tsv 2>/dev/null)

    ERROR_MESSAGE="$(curl $PUBLIC_IP:$PORT 2>&1)"
    
    echo -e "\n\n************************************************************************\n"
    echo -e "\n--> \nIssue description: \n Customer has an ACI already deployed in the resource group $RESOURCE_GROUP\n"
    echo -e "Customer created the Constinaer Instance using the command:"
    echo -e "az container create -g <aci_rg> -n <aci_name> --image mcr.microsoft.com/azuredocs/aci-helloworld --ports 8080\n"
    echo -e "But, the customer is not able to access the Instance using the Public IP and Port. Cx is getting the error message:"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "$ERROR_MESSAGE"
    echo -e "\n¯\_(ツ)_/¯"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "Check the logs for the Container instance using the \"az container logs -n <aci_name> -g <aci_rg>\". Then, verify the Networking configuration of the Container Instance on the Portal and see if there is any mis-configuration.\n"
    echo -e "Once you find the issue, update the Constinaer Instance using the command:"
    echo -e "\naz container create -g <aci_rg> -n <aci_name> --image <aci_image> --ports <required_port>\n"
    echo -e "\nNote that in order to update a specific property of an existing Container Instance, all other properties should be same. For reference: https://docs.microsoft.com/en-us/azure/container-instances/container-instances-update#update-a-container-group\n"
}

function lab_scenario_3_validation () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    UPDATED_PORT=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query ipAddress.ports[].port -o tsv)
    if [ $UPDATED_PORT -eq 80 ]
    then
        echo -e "\n\n========================================================"
        echo -e '\nContainer instance looks good now!\n'
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "Check the logs for the Container instance using the \"az container logs -n <aci_name> -g <aci_rg>\". Then, verify the Networking configuration of the Container Instance on the Portal and see if there is any mis-configuration.\n"
        echo -e "Once you find the issue, update the Constinaer Instance using the command:"
        echo -e "\n az container create -g <aci_rg> -n <aci_name> --image <aci_image> --ip-address Public --ports <required_port>\n"
        echo -e "\n Note that in order to update a specific property of an existing Container Instance, all other properties should be same. For reference: https://docs.microsoft.com/en-us/azure/container-instances/container-instances-update#update-a-container-group\n"
    fi
}

# Lab scenario 4
function lab_scenario_4 () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    CLIENT_ACI_NAME=${ACI_NAME}-client
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    check_resourcegroup_cluster $RESOURCE_GROUP $ACI_NAME

    echo -e "\n--> Deploying resources for lab${LAB_SCENARIO}...\n"

    # Create NSG, VNet and Subnet for ACI

    az network nsg create \
    --name aci-nsg-${USER_ALIAS} \
    --resource-group $RESOURCE_GROUP &>/dev/null 

    az network nsg rule create --resource-group $RESOURCE_GROUP \
    --nsg-name aci-nsg-${USER_ALIAS} --name CustomNSGRule \
    --priority 4096 --source-address-prefixes 10.0.1.0/24 \
    --source-port-ranges '*' --destination-address-prefixes '*' \
    --destination-port-ranges 80 8080 --access Deny \
    --protocol Tcp --description "Deny access on port 80 and 8080." &>/dev/null

    az network vnet create --name aci-vnet-${USER_ALIAS} \
    --resource-group $RESOURCE_GROUP --address-prefix 10.0.0.0/16 \
    --subnet-name aci-subnet-${USER_ALIAS} --subnet-prefix 10.0.0.0/24 &>/dev/null 

    az network vnet subnet update --resource-group $RESOURCE_GROUP \
    --name aci-subnet-${USER_ALIAS} --vnet-name aci-vnet-${USER_ALIAS} \
    --network-security-group aci-nsg-${USER_ALIAS} &>/dev/null 
 

    # Create Subnet for Client ACI

    az network vnet subnet create --name client-subnet-${USER_ALIAS} \
    --resource-group $RESOURCE_GROUP --vnet-name aci-vnet-${USER_ALIAS} \
    --address-prefix 10.0.1.0/24 &>/dev/null 


    # Create the Server ACI
    az container create --name $ACI_NAME \
    --resource-group $RESOURCE_GROUP --image mcr.microsoft.com/azuredocs/aci-helloworld \
    --vnet aci-vnet-${USER_ALIAS} --subnet aci-subnet-${USER_ALIAS} &>/dev/null 

    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    SERVER_IP=$(az container show --resource-group $RESOURCE_GROUP --name $ACI_NAME --query ipAddress.ip --output tsv 2>/dev/null)

    az container create --name ${ACI_NAME}-client \
    --resource-group $RESOURCE_GROUP --image alpine/curl \
    --command-line "/bin/sh -c 'while true; do wget -T 5 --spider $SERVER_IP; sleep 2; done'" \
    --vnet aci-vnet-${USER_ALIAS} --subnet client-subnet-${USER_ALIAS} &>/dev/null

    validate_aci_exists $RESOURCE_GROUP $CLIENT_ACI_NAME

    sleep 15

    ERROR_MESSAGE=$(az container logs --resource-group $RESOURCE_GROUP --name $CLIENT_ACI_NAME | tail -3)

    
    echo -e "\n\n************************************************************************\n"
    echo -e "\n--> \nIssue description: \n Customer has 2 Container Instances deployed in different Subnets of the same VNet in resource group $RESOURCE_GROUP. However, the Client ACI $CLIENT_ACI_NAME, is not able to access the Server ACI $ACI_NAME.\n"

    echo -e "Cx is getting the error message:"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "$ERROR_MESSAGE"
    echo -e "\n-------------------------------------------------------------------------------------\n"
    echo -e "Check the network configuration of both the Container Instances in resource group $RESOURCE_GROUP, and see why the Client ACI is not able to connect to the Server ACI.\n"
    echo -e "Once you find the issue, update the network configuration to allow access from Client ACI to Server ACI."

}

function lab_scenario_4_validation () {
    ACI_NAME=aci-labs-ex${LAB_SCENARIO}-${USER_ALIAS}
    RESOURCE_GROUP=aci-labs-ex${LAB_SCENARIO}-rg-${USER_ALIAS}
    validate_aci_exists $RESOURCE_GROUP $ACI_NAME

    CLIENT_LOGS=$(az container logs --resource-group $RESOURCE_GROUP --name $ACI_NAME-client | tail -3 > client-logs)
    if echo $CLIENT_LOGS | grep -i 'remote file exists' &>/dev/null
    then
        echo -e "\n\n========================================================"
        echo -e '\nConnectivity between the 2 Container instances looks good now!\n'
    else
        echo -e "\n--> Error: Scenario $LAB_SCENARIO is still FAILED\n\n"
        echo -e "Check the logs for the Container instance using the \"az container logs -n <aci_name> -g <aci_rg>\". Then, verify the Networking configuration of the Server/Client ACI on the Portal and see if there is any mis-configuration.\n"
        echo -e "\nHint: that both of the Container Instances are Private, and are deployed inside a Virtual Network. Link: https://docs.microsoft.com/en-us/azure/container-instances/container-instances-virtual-network-concepts#scenarios\n"
    fi
}

#if -h | --help option is selected usage will be displayed
if [ $HELP -eq 1 ]
then
    print_usage_text
    echo -e '"-l|--lab" Lab scenario to deploy (3 possible options)
"-r|--region" region to create the resources
"--version" print version of aci-flp-labs
"-h|--help" help info\n'
    exit 0
fi

if [ $VERSION -eq 1 ]
then
    echo -e "$SCRIPT_VERSION\n"
    exit 0
fi

if [ -z $LAB_SCENARIO ]; then
    echo -e "\n--> Error: Lab scenario value must be provided. \n"
    print_usage_text
    exit 9
fi

if [ -z $USER_ALIAS ]; then
    echo -e "Error: User alias value must be provided. \n"
    print_usage_text
    exit 10
fi

# lab scenario has a valid option
if [[ ! $LAB_SCENARIO =~ ^[1-4]+$ ]];
then
    echo -e "\n--> Error: invalid value for lab scenario '-l $LAB_SCENARIO'\nIt must be value from 1 to 4\n"
    exit 11
fi

# main
echo -e "\n--> ACI Troubleshooting sessions
********************************************

This tool will use your default subscription to deploy the lab environments.
Verifing if you are authenticated already...\n"

# Verify az cli has been authenticated
az_login_check

if [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_1

elif [ $LAB_SCENARIO -eq 1 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_1_validation

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_2

elif [ $LAB_SCENARIO -eq 2 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_2_validation

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_3

elif [ $LAB_SCENARIO -eq 3 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_3_validation

elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 0 ]
then
    check_resourcegroup_cluster
    lab_scenario_4

elif [ $LAB_SCENARIO -eq 4 ] && [ $VALIDATE -eq 1 ]
then
    lab_scenario_4_validation

else
    echo -e "\n--> Error: no valid option provided\n"
    exit 12
fi

exit 0