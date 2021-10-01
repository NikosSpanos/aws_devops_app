#!/bin/bash

if [ -f ./aws_remote_production_server_key ];
then
    rm -rf ./aws_remote_production_server_key
fi

if ! command -v jq
then
    echo "jq command was not found. Installing it..."
    sudo apt-get install jq
else
    echo "jq command is installed in your system."
    echo "Connecting to vm instance, please wait..."
fi

file_key_v2=$(terraform output -json | jq -r '.output_private_key.value' > ./aws_remote_production_server_key)
#file_ip_v2=$(terraform output -json | jq -r '.output_public_ip.value')
#file_ip_v2=$(terraform output -json | jq -r '.output_public_dns_address.value')
file_ip_v2=$(terraform output -json | jq -r '.output_eip_public_ip.value')

chmod 600 ./aws_remote_production_server_key

eval $(ssh-agent)

ssh-add $(realpath aws_remote_production_server_key) #./aws_remote_production_server_key

echo 'SSH key added to .ssh folder under name <aws_remote_production_server_key>.'

ssh -i ./aws_remote_production_server_key -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep -E -q "Permission denied|Connection timed out|Identity file ./aws_remote_production_server_key|Host key verification failed"

if [ $? -eq 1 ]
then
     echo 'Connect to remote server through known hosts'
     ssh -i ./aws_remote_production_server_key ubuntu@$file_ip_v2 -p 22

elif [[ *"./aws_remote_production_server_key"* == $(ssh -i ./aws_remote_production_server_key -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Warning: Identity file ./aws_remote_production_server_key") ]]; 
then
    echo "Public key file not found in root directory"

elif [[ *"Permission"* == $(ssh -i ./aws_remote_production_server_key -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Permission denied") ]];
then
    echo "Permission denied for the ip provided. Check if your ip or key are the latest."

elif [[ *"Connection timed out"* == $(ssh -i ./aws_remote_production_server_key -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Connection timed out") ]];
then
    echo "Invalid port number or public ip has no access to the port provided."

else
    echo 'Connecting through known hosts failed... \
          Deleting host and reconnecting.'
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$file_ip_v2"
    ssh -i ./aws_remote_production_server_key ubuntu@$file_ip_v2 -q -p 22
fi

#rm -rf ./aws_remote_production_server_key
