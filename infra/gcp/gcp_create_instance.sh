#!/bin/bash

# To install gcloud on a Debian based system:
# https://cloud.google.com/sdk/docs/install#deb

# Preconditions to run this script:
# - glcoud tool must be installed and set up to access to GCP resources
# - A project called $PROJECT (see below) must be created
#

# Initialize some pre-defined variables with their default values
DEFAULT_PROJECT=""
DEFAULT_ZONE="us-west1-c"
DEFAULT_SSH_KEY_PATH="."
DEFAULT_STARTUP_SCRIPT_PATH="$PWD"
DEFAULT_STARTUP_SCRIPT_FILENAME="gcp_startup_script.sh"
DEFAULT_MACHINE_TYPE="n2-standard-8"
echo "This script has started " 

usage () {
    echo "Usage: $0 [-p <project>] [-s <stack_id>] [-k <ssh_key_file>] [-z <zone>] [-m <machine_type>] [-h]"
    echo "       <project> The project name used to create the environment in GCP."
    echo "                 The project must exist before running this script."
    echo "                 If not specified, the project called $DEFAULT_PROJECT will be used."
    echo "       <stack_id> A suffix used to append in all resources created in GCP."
    echo "                 If provided, it must be an alphanumeric string."
    echo "       <ssh_key_path> An absolute path where to create the SSH key to access to the environment in GCP."
    echo "                 If not provided, the SSH key will be created in the working directory."
    echo "                 If <stack_id> is provided, a subfolder called <stack_id> will be previously created."
    echo "       <zone> The zone used to create the environment in GCP."
    echo "                 If not specified, the zone $DEFAULT_ZONE will be used."
    echo "       <machine_type> The machine type is used to create a machine of requested type in GCP."
    echo "                 If not specified, the machine type $DEFAULT_MACHINE_TYPE will be used."
    exit 1
}

# Parse input arguments
while getopts p:s:k:z:m:h options
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
	    m) MACHINE_TYPE="${OPTARG}"
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
VM_USERNAME="ubuntu"
ADDRESS_NAME="${VM_PREFIX_NAME}-public-ip$STACK_ID"
ZONE="${ZONE:=$DEFAULT_ZONE}"
REGION="${ZONE%-*}"
MIN_CPU_PLATFORM="Intel Cascade Lake"
QUOTA_CPUS_METRIC="N2_CPUS"
#MACHINE_TYPE="n2-standard-8"
MACHINE_TYPE="${MACHINE_TYPE:=$DEFAULT_MACHINE_TYPE}"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
DISK_SIZE="60GB"
WAN_NETWORK="default"
WAN_SUBNET="default"
MGMT_NETWORK_PREFIX_NAME="internal-management"
MGMT_NETWORK="${MGMT_NETWORK_PREFIX_NAME}$STACK_ID"
MGMT_SUBNET="${MGMT_NETWORK_PREFIX_NAME}-subnet$STACK_ID"
MGMT_RANGE="10.20.0.0/24"
MGMT_NETMASK="${MGMT_RANGE##*/}"
FW_RULE_ALLOW_INTERNAL="${MGMT_NETWORK_PREFIX_NAME}-allow-internal$STACK_ID"
FW_RULE_ALLOW_CUSTOM="${WAN_NETWORK}-allow-custom-ports$STACK_ID"
#FW_RULE_ALLOW_CUSTOM_RULE="tcp:22,tcp:1001-1002,tcp:1011-1013,tcp:1021-1023,tcp:1031,tcp:1041,tcp:1051,tcp:5901,tcp:10000-10100,tcp:18021-18023,tcp:18041,icmp"
FW_RULE_ALLOW_CUSTOM_RULE="tcp:22,tcp:5901,tcp:10000-10100,tcp:18021-18023,tcp:18041,icmp"
STARTUP_SCRIPT_PATH="$DEFAULT_STARTUP_SCRIPT_PATH"
STARTUP_SCRIPT_FILENAME="$DEFAULT_STARTUP_SCRIPT_FILENAME"

if [ "x$STACK_ID" != "x" ] ; then
    SSH_KEY_PATH="${SSH_KEY_PATH}/${STACK_ID:1}"
fi

startup_script="$(find $STARTUP_SCRIPT_PATH -type f -name $STARTUP_SCRIPT_FILENAME)"
if [[ "x$startup_script" == "x" || ! -f $startup_script ]] ; then
    echo "ERROR: A startup script called $STARTUP_SCRIPT_FILENAME must exist inside the working directory (${PWD}) before running this script"
    exit 1
fi

echo "Running some preliminar checks to verify that GCP environment can be created ..."

# Check if project called $PROJECT exists
ret="$(gcloud projects list --filter="projectId:$PROJECT" \
    --format="value(PROJECT_ID)")"

echo "Project is: $ret"

if [ "$ret" != "$PROJECT" ] ; then
    echo "ERROR: A project called $PROJECT must exist before running this script"
    exit 1
fi

# Check if zone $ZONE exists in GCP
ret="$(gcloud compute zones list --project $PROJECT \
    --filter="name=$ZONE" \
    --format="value(NAME)")"

if [ "$ret" != "$ZONE" ] ; then
    echo "ERROR: A zone called $ZONE does not exist in GCP."
    echo "       Please check the available zones in GCP by running:"
    echo "       gcloud compute zones list"
    exit 1
fi

# Check if zone $ZONE is UP
ret="$(gcloud compute zones list --project $PROJECT \
    --filter="name=$ZONE" \
    --format="value(STATUS)")"

if [ "$ret" != "UP" ] ; then
    echo "ERROR: Zone $ZONE is not up and running."
    echo "       Please try it later or use another zone."
    echo "       To check the available zones in GCP by running:"
    echo "       gcloud compute zones list"
    exit 1
fi

# Check if required CPU platform $MIN_CPU_PLATFORM is available in region $REGION
gcloud compute zones describe $ZONE \
    --project $PROJECT \
    --flatten='availableCpuPlatforms[]' \
    --format='get(availableCpuPlatforms)' | grep -q "$MIN_CPU_PLATFORM"

if [ $? -ne 0 ] ; then
    echo "ERROR: $MIN_CPU_PLATFORM is not an available CPU platform in region $REGION"
    exit 1
fi

# Check if current GCP quotas allow to create the environment
cpus_quota="$(gcloud compute regions describe $REGION \
    --project $PROJECT \
    --flatten='quotas[]' \
    --format='get(quotas)' | grep "metric=${QUOTA_CPUS_METRIC};")"

cpus_quota_limit=$(echo $cpus_quota | grep -Eo "limit=[0-9]+" | cut -d '=' -f2)
cpus_quota_usage=$(echo $cpus_quota | grep -Eo "usage=[0-9]+" | cut -d '=' -f2)
cpus_machine_type=$(gcloud compute machine-types describe $MACHINE_TYPE \
    --zone=$ZONE \
    --project $PROJECT \
    --format='get(guestCpus)')

if [ $(( $cpus_quota_usage + $cpus_machine_type )) -gt $cpus_quota_limit  ] ; then
    echo "ERROR: Current GCP quota (${QUOTA_CPUS_METRIC}) for region $REGION does not allow to create a new instance."
    echo "       Current usage: $cpus_quota_usage"
    echo "       Current limit: $cpus_quota_limit"
    echo "       CPUs of machine type ${MACHINE_TYPE}: $cpus_machine_type"
    echo "       Please use another region, or request a quota increase"
    exit 1
fi

echo "The GCP environment will be created inside the project $PROJECT"

# Get the newest GCP official image for Ubuntu 20.04 LTS
#image="$(gcloud compute images list --project=$PROJECT \
#    --filter="family~ 'ubuntu-2004-lts$'" \
#    --format="value(NAME)" \
#    --sort-by="~creationTimestamp" \
#    --limit=1)"
#echo "Image Project: $image"

# Create network for internal management purposes inside the VM instance
echo "Creating network called $MGMT_NETWORK for internal management purposes inside the VM instance ..."
gcloud compute networks create $MGMT_NETWORK \
    --subnet-mode=auto \
    --project=$PROJECT

# Create a subnet attached to created internal management network used inside the VM instance
echo "Creating a subnet called $MGMT_SUBNET attached to created internal management network used inside the VM instance ..."
gcloud compute networks subnets create $MGMT_SUBNET \
    --network=$MGMT_NETWORK \
    --range=$MGMT_RANGE \
    --project=$PROJECT \
    --region=$REGION

# Create firewall rule to allow any internal traffic
echo "Creating firewall rule called $FW_RULE_ALLOW_INTERNAL to allow any internal traffic ..."
gcloud compute firewall-rules create $FW_RULE_ALLOW_INTERNAL \
    --network $MGMT_NETWORK \
    --allow all \
    --source-ranges $MGMT_RANGE \
    --project=$PROJECT

# Create firewall rule to allow SSH, custom ports for SSH access to the environment, and ICMP traffic from anywhere
echo "Creating firewall rule called $FW_RULE_ALLOW_CUSTOM to allow SSH, custom ports for SSH access to the environment, and ICMP traffic from anywhere ..."
gcloud compute firewall-rules create $FW_RULE_ALLOW_CUSTOM \
    --network $WAN_NETWORK \
    --allow $FW_RULE_ALLOW_CUSTOM_RULE \
    --project=$PROJECT

# Create SSH key to be used to connect to the VM instance
echo "Creating SSH key to be used to connect to the VM instance ..."

if [ "$SSH_KEY_PATH" != "$DEFAULT_SSH_KEY_PATH" ] ; then
    mkdir -p $SSH_KEY_PATH
fi

ssh_privkey_file="${SSH_KEY_PATH}/${PROJECT}_ssh_key"
ssh_pubkey_file="${ssh_privkey_file}.pub"
ssh-keygen -t rsa -f $ssh_privkey_file -q -N "" <<<y
chmod 600 $ssh_privkey_file
public_key="${VM_USERNAME}:$(cut -d ' ' -f1,2 $ssh_pubkey_file)"
echo "Public key (username:pubkey format):"
echo "$public_key"

# Create VM instance
echo "Creating VM instance called $VM_NAME ..."
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT \
    --enable-nested-virtualization \
    --min-cpu-platform="$MIN_CPU_PLATFORM" \
    --machine-type=$MACHINE_TYPE \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT \
    --boot-disk-size=$DISK_SIZE \
    --metadata=ssh-keys="$public_key" \
    --metadata-from-file=startup-script=$startup_script \
    --network-interface network=$WAN_NETWORK,subnet=$WAN_SUBNET,address='' \
    --network-interface network=$MGMT_NETWORK,subnet=$MGMT_SUBNET,no-address

# Get the private IP behind NAT assigned to the VM instance
wan_private_ip="$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT \
    --format='get(networkInterfaces[0].networkIP)')"

# Get the private IP range behind NAT assigned to the VM instance
wan_private_range="$(gcloud compute networks subnets describe $WAN_SUBNET \
    --project=$PROJECT \
    --region=$REGION \
    --format='get(ipCidrRange)')"

wan_private_netmask="${wan_private_range##*/}"

# Get the ephemeral public IP assigned to the VM instance
public_ip="$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')"

# Get the internal management network private IP assigned to the VM instance
mgmt_private_ip="$(gcloud compute instances describe $VM_NAME \
    --zone=$ZONE \
    --project=$PROJECT \
    --format='get(networkInterfaces[1].networkIP)')"

# Dump all GCP environment info into a file
env_vars_file="${SSH_KEY_PATH}/${PROJECT}_vars_file"
echo "public_ip=\"$public_ip\"" > $env_vars_file
echo "wan_private_ip=\"${wan_private_ip}/$wan_private_netmask\"" >> $env_vars_file
echo "mgmt_private_addr=\"${mgmt_private_ip}/$MGMT_NETMASK\"" >> $env_vars_file

# Reserve the previous ephemeral public IP assigned to the VM instance
echo "Reserving the previous ephemeral public IP ($public_ip) assigned to the VM instance called $VM_NAME with name $ADDRESS_NAME ..."
gcloud compute addresses create $ADDRESS_NAME \
    --addresses=$public_ip \
    --project=$PROJECT \
    --region=$REGION

echo "$VM_NAME Public IP: $public_ip"
echo "$VM_NAME Private IP (behind NAT): ${wan_private_ip}/$wan_private_netmask"
echo "$VM_NAME Internal Management Network Private IP: ${mgmt_private_ip}/$MGMT_NETMASK"

# Remove ssh known host for reserved public ip in order to avoid ssh man-in-the-middle attack detection
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "$public_ip"

echo "Waiting until the VM instance called $VM_NAME is ready ..."
result=1
timeout=30
ssh_options="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no"
for (( ; ; )) ; do
    status="$(ssh $ssh_options -i $ssh_privkey_file ${VM_USERNAME}@${public_ip} echo ok 2>&1)"
    result=$?
    if [ $result -eq 0 ]; then
        echo "SSH connection to the VM instance called $VM_NAME is ready"
        break
    fi
    if [ $result -eq 255 ]; then
        if [[ "$status" == *"Permission denied"* ]] ; then
            echo "ERROR: VM instance called $VM_NAME is reachable, but SSH permission denied has occurred"
            exit 1
        fi
    fi
    timeout=$((timeout-1))
    if [ $timeout -eq 0 ]; then
        echo "ERROR: SSH connection to the VM instance called $VM_NAME failed (timeout has been reached)"
        exit 1
    fi
    sleep 5
done

echo "Waiting until the VM instance called $VM_NAME executes the startup script $STARTUP_SCRIPT_FILENAME ..."
result=1
timeout=60
ssh_options="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no"
startup_script_status_file="/tmp/gcp_startup_script_status"
for (( ; ; )) ; do
    status="$(ssh $ssh_options -i $ssh_privkey_file ${VM_USERNAME}@${public_ip} cat $startup_script_status_file 2>&1)"
    result=$?
    if [[ $result -eq 0 && "$status" == "ok" ]]; then
        echo "The VM instance called $VM_NAME has executed the startup script $STARTUP_SCRIPT_FILENAME successfully"
        break
    fi
    timeout=$((timeout-1))
    if [ $timeout -eq 0 ]; then
        echo "ERROR: Startup script $STARTUP_SCRIPT_FILENAME executed inside the VM instance called $VM_NAME failed (timeout has been reached)"
        echo "       Startup script status return code: $result"
        echo "       Startup script status output: $status"
        exit 1
    fi
    sleep 5
done


echo "The GCP environment has been created successfully"
echo "To connect to the VM instance called $VM_NAME via SSH:"
echo "ssh -i $ssh_privkey_file ${VM_USERNAME}@${public_ip}"
exit 0
