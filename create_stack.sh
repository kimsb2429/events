read -p "Stack Name: " stack_name
read -p "Template Filepath (your-template.yaml): " template_filepath
aws cloudformation delete-stack --stack-name $stack_name 
aws cloudformation wait stack-delete-complete --stack-name $stack_name
aws cloudformation create-stack --stack-name $stack_name --template-body file://$template_filepath
aws cloudformation wait stack-create-complete --stack-name $stack_name
sleep 60
ip=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='wcd-final-stack'].Outputs[].OutputValue" --output text)
echo $ip
open http://$ip:8080/nifi/
ssh -i prosody.pem ec2-user@$ip