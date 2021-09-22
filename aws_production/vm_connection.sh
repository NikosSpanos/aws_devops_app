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
file_ip_v2=$(terraform output -json | jq -r '.output_public_ip.value')

if command ssh -vvv -i ./mykey ubuntu@$file_ip_v2 ;
then
    echo 'Connect to remote server through known hosts'
    ssh -vvv -i ./mykey ubuntu@$file_ip_v2
else
    echo 'Connecting through known hosts failed... \
    Deleting host and reconnecting.'
    ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$file_ip_v2"
    ssh -vvv -i ./mykey ubuntu@$file_ip_v2

chmod 600 ./mykey

rm -rf ./mykey
