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

# Assumptions / Notes

Assumptions are minimized by making this self contained, however:
- It as assumed that the AWS credentials you configure have policies attached to allow this user to interact with all the AWS services listed in **Architecture**
- It is assumed that this basic example could be easily applied in a multi-tenant environment, yet I do not actually model a true multi-tenant model here specifically. There are several approaches I can think of to create a true multi-tenant environment... I am only running single service, task, db and container counts in this prototype. I assume it can be easily extended as needed but did not have the time to fully test that out. However, the architecture here seems basically sound and I expect it would not take a lot of effort to model this out further.. 

Notes
- For this example, I just autogenerate the database password instead of setting it manually as a variable (or prompting)
- I do have the database user set in a variable (terraform.tvars). It defaults to "metabase" but can be changed.
- I do encrypt the database user string, store in AWS Secrets Manager and have it injected into the task. This is done as more of an example of how we may want to treat the username in a multi-tenant environment more than being particularly useful for this example 


# Usage

`terraform init`
`terraform apply`

