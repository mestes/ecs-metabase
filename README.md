# Introduction

This is an example implementation of managing secrets for docker containers running in AWS ECS that uses AWS Secrets Manager to store encrypted secrets and these secrets get injected to the example task securely via the ecs docker secrets configuration. 

# Requirements

- An AWS account
- Terraform installed on local machine
- AWS IAM credentials that have permissions for managing AWS ECS and AWS Secrets Manager services
- Your AWS credentials setup in your environment for terraform to use. There are a lot of ways to do this. If you have the aws cli installed, you can probably just run `aws configure`

# Architecture

This example attempts to be as self contained as possible by creating a vpc to contain all resources this example requires.
It creates:
- 1 vpc in user specified region (set in terraform.tfvars)  
- 2 subnets associated with user specified AZs (set in terraform.tfvars)
- Custom ecsTaskExecutionRole that can read the secrets from AWS Secrets Manager
- Security group for the metabase container
- Security group for the postgres db cluster
- User specified database username (set in terraform.tfvars)
- Randomly generated database password
- Secrets in AWS Secrets Manager for storing the database username and password
- RDS Aurora cluster using the Postgresql engine 
- Task definition (FARGATE) for the metabase container configuration
- ECS Service for the metabase task definition

# Assumptions

I tried to make this example rather self contained

# Usage

Make sure you have installed terraform! 
Make sure you have configured your aws credentials! (if you have aws cli installed, run aws configure)


