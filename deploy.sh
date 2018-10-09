aws s3 sync app/ s3://storage-kalleh/cfn/app
aws cloudformation package --template-file template.yml --s3-bucket storage-kalleh --s3-prefix 'cfn/infrastructure' --output-template-file template-deploy.yml
aws cloudformation deploy --template-file template-deploy.yml --stack-name gureume --capabilities CAPABILITY_NAMED_IAM