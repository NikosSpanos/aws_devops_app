#!/bin/bash

if [ -f ./mykey ];
then
    rm -rf ./mykey
fi

if ! command -v jq
then
    echo "jq command was not found. Installing it..."
    sudo apt-get install jq
else
    echo "jq command is installed in your system."
    echo "Connecting to vm instance, please wait..."
fi

file_key_v2=$(terraform output -json | jq -r '.output_private_key.value' > ./mykey)
#file_ip_v2=$(terraform output -json | jq -r '.output_public_ip.value')
#file_ip_v2=$(terraform output -json | jq -r '.output_public_dns_address.value')
file_ip_v2=$(terraform output -json | jq -r '.output_eip_public_ip.value')

chmod 600 ./mykey

ssh -i ./mykey -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep -E -q "Permission denied|Connection timed out|Identity file ./mykey"
if [ $? -eq 1 ]
then
     echo 'Connect to remote server through known hosts'
     ssh -i ./mykey ubuntu@$file_ip_v2 -q -p 22
#elif command ssh -i ./mykey -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Identity file ./mykey" ==

elif [[ *"./mykey"* == $(ssh -i ./mykey -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Warning: Identity file ./mykey") ]]; 
then
    echo "Public key file not found in root directory"

elif [[ *"Permission"* == $(ssh -i ./mykey -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Permission denied") ]];
then
    echo "Permission denied for the ip provided. Check if your ip or key are the latest."

elif [[ *"Connection timed out"* == $(ssh -i ./mykey -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Connection timed out") ]];
then
    echo "Invalid port number or public ip has no access to the port provided."

else
    echo 'Connecting through known hosts failed... \
          Deleting host and reconnecting.'
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$file_ip_v2"
    ssh -i ./mykey ubuntu@$file_ip_v2 -q -p 22
fi

rm -rf ./mykey
