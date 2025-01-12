#!/bin/bash
STACK_NAME="gurum-platform"
ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
REGION=$(aws configure get region)
S3_BUCKET="gurum-deployment-artifacts-$ACCOUNT_ID-$REGION"

# Only create the artifacts bucket if one does not exist.
if aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating initial artifacts bucket"
    aws s3 mb "s3://$S3_BUCKET"
    aws s3api put-bucket-encryption --bucket $S3_BUCKET --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
    aws s3api put-public-access-block \
    --bucket $S3_BUCKET \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

# Only configure public hosted zone if it's not already configured
if ! aws ssm get-parameters --names "/gurum/platform/domain-name" 2>&1 | grep -q '"Name": "/gurum/platform/domain-name"'; then
    echo "No Platform Doman Name specified. Enter FQDN for wildcard cert i.e. (apps.example.com):"
    read PLATFORM_DOMAIN_NAME
    aws ssm put-parameter \
        --name "/gurum/platform/domain-name" \
        --type "String" \
        --description "Gurum Platform Domain FQDN." \
        --value $PLATFORM_DOMAIN_NAME
fi

aws cloudformation package --template-file template.yaml --s3-bucket $S3_BUCKET --s3-prefix 'cfn' --output-template-file template-deploy.yaml
aws cloudformation deploy --template-file template-deploy.yaml --stack-name $STACK_NAME --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND
