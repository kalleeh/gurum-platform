aws s3 sync app/ s3://storage-kalleh/cfn/app
aws cloudformation package --template-file master.yml --s3-bucket storage-kalleh --s3-prefix 'cfn/infrastructure' --output-template-file master-deploy.yml
aws cloudformation deploy --template-file master-deploy.yml --stack-name gureume --capabilities CAPABILITY_NAMED_IAM