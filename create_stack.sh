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
ip=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='wcd-final-stack'].Outputs[].OutputValue" --output text)
echo $ip
response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://$ip:8080)
while [ $response -ne '200' ]
do
    sleep 10
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://$ip:8080)
    echo $response
done
process_group_id=$(curl http://$ip:8080/nifi-api/flow/process-groups/root | jq -r '.processGroupFlow.id')
curl -k -F template=@$nifi_template_filepath -X POST http://$ip:8080/nifi-api/process-groups/$process_group_id/templates/upload
open http://$ip:8080/nifi/
ssh -i prosody.pem ec2-user@$ip