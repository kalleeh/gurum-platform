S3_BUCKET="storage-kalleh"
STACK_NAME="gureume-platform"

aws s3 sync cfn/ s3://$S3_BUCKET/cfn/
aws cloudformation package --template-file template.yaml --s3-bucket $S3_BUCKET --s3-prefix 'platform-cfn' --output-template-file template-deploy.yaml
aws cloudformation deploy --template-file template-deploy.yaml --stack-name $STACK_NAME --capabilities CAPABILITY_NAMED_IAM