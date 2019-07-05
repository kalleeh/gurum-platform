# Gureume Platform Template

This reference architecture provides a set of YAML templates for deploying a container cluster and supporting functionality to the Gureume Management API with [AWS CloudFormation](https://aws.amazon.com/cloudformation/).

## Overview

![architecture-overview](images/architecture-overview.png)

The architecture consists of two parts, the supporting platform and the management API.

This repository consists of a set of nested templates to deploy the supporting platform:

- A tiered [VPC](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Introduction.html) with public and private subnets, spanning an AWS region.
- A highly available ECS cluster deployed across two [Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html) in an [Auto Scaling](https://aws.amazon.com/autoscaling/) group and that are AWS SSM enabled.
- A pair of [NAT gateways](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/vpc-nat-gateway.html) (one in each zone) to handle outbound traffic.
- An [Application Load Balancer (ALB)](https://aws.amazon.com/elasticloadbalancing/applicationloadbalancer/) to the public subnets to handle inbound traffic.
- ALB path-based routes for each ECS service to route the inbound traffic to the correct service.
- Centralized container logging with [Amazon CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html).
- A [Lambda Function](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) and [Auto Scaling Lifecycle Hook](https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html) to [drain Tasks from your Container Instances](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/container-instance-draining.html) when an Instance is selected for Termination in your Auto Scaling Group.

## Template details

The templates below are included in this repository and reference architecture:

| Template | Description |
| --- | --- |
| [template.yaml](template.yaml) | This is the master template - deploy it to CloudFormation and it includes all of the others automatically. |
| [cfn/vpc.yaml](infrastructure/vpc.yaml) | This template deploys a VPC with a pair of public and private subnets spread across two Availability Zones. It deploys an [Internet gateway](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Internet_Gateway.html), with a default route on the public subnets. It deploys a pair of NAT gateways (one in each zone), and default routes for them in the private subnets. |
| [cfn/load-balancers.yaml](infrastructure/load-balancers.yaml) | This template deploys an ALB to the public subnets, which exposes the various ECS services. It is created in in a separate nested template, so that it can be referenced by all of the other nested templates and so that the various ECS services can register with it. |
| [cfn/ecs-cluster.yaml](infrastructure/ecs-cluster.yaml) | This template deploys an ECS cluster to the private subnets using an Auto Scaling group and installs the AWS SSM agent with related policy requirements. |
| [cfn/lifecyclehook.yaml](infrastructure/lifecyclehook.yaml) | This template deploys a Lambda Function and Auto Scaling Lifecycle Hook to drain Tasks from your Container Instances when an Instance is selected for Termination in your Auto Scaling Group.

After the CloudFormation templates have been deployed, the [stack outputs](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/outputs-section-structure.html) contain a series of parameters needed for configuration of the API and the CLI.

The ECS instances should also appear in the Managed Instances section of the EC2 console.

## Deployment Instructions (Quick Start)

### Prerequisites

#### Platform Domain Name

As part of the deployment the template will create a wildcard certificate using AWS Certificate Manager. This domain name will then be used to host your platform applications by registering a Route 53 record in the Hosted Zone.
The deployment of the Route 53 Hosted Zone is not part of this stack since it's likely you already have one or want to manage it outside the lifecycle of this platform. You are likely to want a Public Hosted Zone to be accessible from outside of your AWS Account, you can read more about how to provision one in the [documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html).

#### Setup commands

Run the below command to package all the deployment artifacts, upload them to the S3 bucket and create the CloudFormation stacks.
If you run the command for the first time you will be asked to provide a fully qualified domain name (FQDN) for the wildcart ceriticate. Enter the domain name configured as above.

```sh
./deploy.sh
```

All the relevant output parameters should be written to parameter store under the /gureume/ namespace.

## Manual Deployment Instructions

For manual steps and customizations to the platform, see the [admin guide](docs/admin-guide.md).

### Update an ECS service parameters

The platform users handle the definition of the container image they want to use, however you can override certain properties in the app.yaml files being deployed by the platform.

To adjust the rollout parameters (min/max number of tasks/containers to keep in service at any time), you need to configure `DeploymentConfiguration` for the ECS service.

For example:

```YAML
Service:
  Type: AWS::ECS::Service
    Properties:
      ...
      DesiredCount: 4
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 50
```

## Platform Documentation

### Service Discovery

Service Discovery is implemented using AWS CloudMap. For each platform deployed there is a service discovery namespace provisioned where the apps register themselves as they come online. These should be discoverable by all the services in the platform by DNS using the service name plus the cluster namespace.

For example a service with the name MyApp1 would be discoverable by other services in the cluster by querying myapp1.gureume-platform.local.

### ECS

ECS is running in Fargate mode.

### Backing Services

Currently the only supported backing service is S3. When you create an S3 service it is not bound to any application.
To bind an application update the service bindings property and specify a comma-separated list of the applications you want to add permissions for.
Using the CLI it would look something lie,

```bash
gureume service update MyS3 --service-bindings app1,app2
```

This will automatically modify the bucket policy to give read/write access to the IAM Role that the applications are running as.
