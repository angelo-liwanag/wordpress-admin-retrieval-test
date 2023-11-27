# This file contains the SSH commands to retrieve the default admin password for Bitnami instances.

#!/usr/bin/env bash 
set -eu -o pipefail

instance=$1

# Access the instance details
giad=$(aws lightsail get-instance-access-details --protocol ssh --instance-name $instance | jq '.accessDetails')
userhost=$(jq -r '.ipAddress' <<<$giad)
username=$(jq -r '.username' <<<$giad)

# Make a temporary directory that will be automatically removed when this script exits for any reason
work_dir=$(mktemp -d)
trap "{ rm -rf $work_dir; }" EXIT

# Gather the known host keys of the instance
kh_lines=$(jq -r --arg arg_host $userhost '.hostKeys[] | $arg_host+" "+.algorithm+" "+.publicKey' <<<$giad)
while read kh_line; do
    echo "$kh_line" >> $work_dir/hostkeys
done <<<"$kh_lines"

# Store SSH key materials
jq -r '.certKey'    <<<$giad > "$work_dir/key-cert.pub"
jq -r '.privateKey' <<<$giad > "$work_dir/key"
chmod 600 "$work_dir/key"

# Connect to instance
shift
ssh \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile=$work_dir/hostkeys \
  -i $work_dir/key \
  $username@$userhost \
  chmod +x lightsail_connect \
  ./lightsail_connect $instance \
  $@ 

cat bitnami_application_password
