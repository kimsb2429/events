#!/bin/bash
set -e
read -p "Stack Name [wcd-final-stack]: " stack_name
stack_name=${stack_name:-wcd-final-stack}
read -p "Template Filepath [wcd-final-stack.yaml]: " template_filepath
template_filepath=${template_filepath:-wcd-final-stack.yaml}
read -p "NiFi Template Filepath [twitter.xml]: " nifi_template_filepath
nifi_template_filepath=${nifi_template_filepath:-twitter.xml}
aws cloudformation delete-stack --stack-name $stack_name 
aws cloudformation wait stack-delete-complete --stack-name $stack_name
aws cloudformation create-stack --stack-name $stack_name --template-body file://$template_filepath
aws cloudformation wait stack-create-complete --stack-name $stack_name
sleep 60
ip=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='$stack_name'].Outputs[].OutputValue" --output text)
echo $ip
sleep 100
# until [[ $(curl --insecure --write-out '%{http_code}' --silent --output /dev/null http://$ip:8080) ]]; do sleep 10; done
process_group_id=$(curl http://$ip:8080/nifi-api/flow/process-groups/root | jq -r '.processGroupFlow.id')
curl -k -F template=@$nifi_template_filepath -X POST http://$ip:8080/nifi-api/process-groups/$process_group_id/templates/upload
python3 update_nifi_sensitive_data.py $ip
open http://$ip:8080/nifi/
echo "ssh -i prosody.pem ec2-user@$ip"
ssh -i prosody.pem ec2-user@$ip