ip=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='wcd-final-stack'].Outputs[].OutputValue" --output text)
echo $ip
response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://$ip:8080)
echo $response
while [ $response -ne 200 ]
do
    sleep 10
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null http://$ip:8080)
    echo $response
done
process_group_id=$(curl http://$ip:8080/nifi-api/flow/process-groups/root | jq -r '.processGroupFlow.id')
curl -k -F template=@$nifi_template_filepath -X POST http://$ip:8080/nifi-api/process-groups/$process_group_id/templates/upload
open http://$ip:8080/nifi/
ssh -i prosody.pem ec2-user@$ip