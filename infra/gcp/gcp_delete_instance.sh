#!/bin/bash

# To install gcloud on a Debian based system:
# https://cloud.google.com/sdk/docs/install#deb

# Preconditions to run this script:
# - glcoud tool must be installed and set up to access to GCP resources
# - A project called $PROJECT (see below) must be created
# - This script is run from Jenkins job "Blueprint Testing Suite GCP - Dual WAN Pipeline":
#   https://ci.flexiwan.com/job/Blueprint%20Testing%20Suite%20GCP%20-%20Dual%20WAN%20Pipeline/ 
#
#   To use it outside Jenkins, perform necessary changes

# Initialize some pre-defined variables with their default values
DEFAULT_PROJECT="flexiwan-regression-tests"
DEFAULT_ZONE="us-west1-c"
DEFAULT_SSH_KEY_PATH="."

function usage {
    echo "Usage: $0 [-p <project>] [-s <stack_id>] [-k <ssh_key_file>] [-z <zone>] [-h]"
    echo "       <project> The project name where the GCP environment was created."
    echo "                 The project must exist before running this script."
    echo "                 If not specified, the project called $DEFAULT_PROJECT will be used."
    echo "       <stack_id> A suffix used to append in all resources created in GCP."
    echo "                  If provided, it must be an alphanumeric string."
    echo "       <ssh_key_path> An absolute path where to remove the SSH key to access to the environment in GCP."
    echo "                      If not provided, the SSH key will be removed in the working directory."
    echo "                      If <stack_id> is provided, a subfolder called <stack_id> will be removed."
    echo "       <zone> The zone where the GCP environment was created."
    echo "              If not specified, the zone $DEFAULT_ZONE will be used."
    exit 1
}

# Parse input arguments
while getopts p:s:k:z:h options
do
    case "$options" in
        p) PROJECT="${OPTARG}"
           ;;
        s) STACK_ID="-${OPTARG}"
           ;;
        k) SSH_KEY_PATH="${OPTARG}"
           ;;
        z) ZONE="${OPTARG}"
           ;;
        h|*) usage
             ;;
    esac
done
shift $(($OPTIND - 1))

if [[ "x$STACK_ID" != "x" && ! "$STACK_ID" =~ ^-[0-9a-zA-Z]+$ ]] ; then
    echo "ERROR: <stack_id> must be an alphanumeric string"
    exit 1
fi

# Initialize some pre-defined variables
PROJECT="${PROJECT:=$DEFAULT_PROJECT}"
SSH_KEY_PATH="${SSH_KEY_PATH:=$DEFAULT_SSH_KEY_PATH}"
VM_PREFIX_NAME="${PROJECT}-instance-sasewan"
VM_NAME="${VM_PREFIX_NAME}$STACK_ID"
ADDRESS_NAME="${VM_PREFIX_NAME}-public-ip$STACK_ID"
ZONE="${ZONE:=$DEFAULT_ZONE}"
REGION="${ZONE%-*}"
WAN_NETWORK="default"
MGMT_NETWORK_PREFIX_NAME="internal-management"
MGMT_NETWORK="${MGMT_NETWORK_PREFIX_NAME}$STACK_ID"
MGMT_SUBNET="${MGMT_NETWORK_PREFIX_NAME}-subnet$STACK_ID"
FW_RULE_ALLOW_INTERNAL="${MGMT_NETWORK_PREFIX_NAME}-allow-internal$STACK_ID"
FW_RULE_ALLOW_CUSTOM="${WAN_NETWORK}-allow-custom-ports$STACK_ID"

if [ "x$STACK_ID" != "x" ] ; then
    SSH_KEY_PATH="${SSH_KEY_PATH}/${STACK_ID:1}"
fi


# Check if project called $PROJECT exists
ret="$(gcloud projects list --filter="projectId:$PROJECT" \
    --format="value(PROJECT_ID)")"

if [ "$ret" != "$PROJECT" ]; then
    echo "ERROR: A project called $PROJECT must exist before running this script"
    exit 1
fi

echo "The GCP environment inside the project $PROJECT will be deleted"

# Remove SSH key used to connect to the VM instance and GCP environment info file
echo "Removing the SSH key used to connect to the VM instance and GCP environment info file ..."
ssh_privkey_file="${SSH_KEY_PATH}/${PROJECT}_ssh_key"
ssh_pubkey_file="${ssh_privkey_file}.pub"
env_vars_file="${SSH_KEY_PATH}/${PROJECT}_vars_file"
rm -f $ssh_privkey_file $ssh_pubkey_file $env_vars_file

# If a directory called $STACK_ID were created,
# just remove it if it's empty after above files deletion
if [ "x$STACK_ID" != "x" ] ; then
    rmdir $SSH_KEY_PATH
fi

# Delete the VM instance
echo "Deleting the VM instance called $VM_NAME ..."
gcloud compute instances delete $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT \
    --quiet

# Release the public IP assigned to the VM instance
echo "Releasing the public IP assigned to the VM instance with name $ADDRESS_NAME ..."
gcloud compute addresses delete $ADDRESS_NAME \
    --project=$PROJECT \
    --region=$REGION \
    --quiet

# Delete firewall rules
echo "Deleting firewall rule called $FW_RULE_ALLOW_INTERNAL ..."
gcloud compute firewall-rules delete $FW_RULE_ALLOW_INTERNAL \
    --project=$PROJECT \
    --quiet

echo "Deleting firewall rule called $FW_RULE_ALLOW_CUSTOM ..."
gcloud compute firewall-rules delete $FW_RULE_ALLOW_CUSTOM \
    --project=$PROJECT \
    --quiet

# Delete the subnet attached to the internal management network used inside the VM instance
echo "Deleting the subnet called $MGMT_SUBNET attached to the internal management network used inside the VM instance ..."
gcloud compute networks subnets delete $MGMT_SUBNET \
    --project=$PROJECT \
    --region=$REGION \
    --quiet

# Delete the internal management network used inside the VM instance
echo "Deleting the internal management network called $MGMT_NETWORK used inside the VM instance ..."
gcloud compute networks delete $MGMT_NETWORK \
    --project=$PROJECT \
    --quiet

echo "The GCP environment has been deleted successfully"
exit 0
