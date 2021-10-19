#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -n EnvironmentName -p TerraformWorkingDirectory" #$0 script name (i.e vm_connection.sh
   echo -e "\t-n The environment name of the publick key. Values accepted production/ development"
   echo -e "\t-p Terraform's working directory. Typically is the directory where the terraform has been initialized."
   echo -e "\t-p User HOME directory. Typically is the path of the environment variable '(dollar sign)HOME'"
   exit 1 # Exit script after printing help
}

while getopts "n:p:h:" opt
do
   case "$opt" in
      n ) EnvironmentName="$OPTARG" ;;
      p ) TerraformWorkingDirectory="$OPTARG" ;;
      h ) HomeDirectory="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$EnvironmentName" ] || [ -z "$TerraformWorkingDirectory" || -z "$HomeDirectory"]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# if [[ $# -eq 0 ]] ; then # $# checks that 0 argument was given to bash execution
#     ${1?"Usage: $0 public-key-name argument (production/development) not provided"}
#     exit 0
# fi
echo ""
echo "Environment: $EnvironmentName"
echo "Terraform working directory: $TerraformWorkingDirectory"
echo ""

public_key_name="aws_remote_$1_server_key"

echo -e "The public key of the server will be named: $public_key_name\n"

#----------------------------------------------------------------------------------------------------------------------
cd $TerraformWorkingDirectory #(i.e ./aws_production/), change to sub-directory

if [ -f ./$public_key_name ];
then
    rm -rf ./$public_key_name
fi

if ! command -v jq
then
    echo -e "jq command was not found. Installing it...\n"
    sudo apt-get install jq
else
    echo -e "jq command is installed in your system.\n"
    echo -e "Connecting to vm instance, please wait...\n"
fi

file_key_v2=$(terraform output -json | jq -r '.output_private_key.value' > ./$public_key_name)
file_ip_v2=$(terraform output -json | jq -r '.output_eip_public_ip.value')

chmod 600 ./$public_key_name

eval ssh-agent
ssh-add $(realpath $public_key_name) #there is an issue when executing this command from bash it fails to add the ssh key to ssh-agent. When the same command is executed from the terminal, the key is added successfully
ssh-add -L

ssh -i ./$public_key_name -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep -E -q "Permission denied|Connection timed out|Identity file ./$public_key_name|Host key verification failed"

if [ $? -eq 1 ]
then
     echo -e 'Connect to remote server through known hosts\n'
     ssh -i ./$public_key_name ubuntu@$file_ip_v2 -p 22

elif [[ *"./$public_key_name"* == $(ssh -i ./$public_key_name -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Warning: Identity file ./$public_key_name") ]]; 
then
    echo -e "Public key file not found in root directory\n"

elif [[ *"Permission"* == $(ssh -i ./$public_key_name -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Permission denied") ]];
then
    echo -e "Permission denied for the ip provided. Check if your ip or key are the latest.\n"

elif [[ *"Connection timed out"* == $(ssh -i ./$public_key_name -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o ChallengeResponseAuthentication=no -p 22 ubuntu@$file_ip_v2 2>&1 exit | grep "Connection timed out") ]];
then
    echo -e "Invalid port number or public ip has no access to the port provided.\n"

else
    echo -e 'Connecting through known hosts failed... \n
          Deleting host and reconnecting.\n'
    ssh-keygen -f "$HomeDirectory/.ssh/known_hosts" -R "$file_ip_v2"
    ssh -i ./$public_key_name ubuntu@$file_ip_v2 -q -p 22
fi

cd - #return to parent directory
