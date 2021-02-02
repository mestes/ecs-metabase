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

# Alternatives Considered
- AWS Systems Manager Parameter Store could be used instead of AWS Secrets Manager. I chose AWS Secrets Manager because I was thinking I would explore the secrets rotation either now or as a follow up.
- Hashicorp Consul, Vault could be used instead as well. In past experiences, I found getting those working to be pretty time heavy vs the results I could get just using AWS services.  

# Assumptions / Notes

Assumptions are minimized by making this self contained, however:
- It as assumed that the AWS credentials you configure have policies attached to allow this user to interact with all the AWS services listed in **Architecture**
- It is assumed that this basic example could be easily applied in a multi-tenant environment, yet I do not actually model a true multi-tenant model here specifically. There are several approaches I can think of to create a true multi-tenant environment... I am only running single service, task, db and container counts in this prototype. I assume it can be easily extended as needed but did not have the time to fully test that out. However, the architecture here seems basically sound and I expect it would not take a lot of effort to model this out further.. 

Notes
- For this example, I just autogenerate the database password instead of setting it manually as a variable (or prompting)
- I do have the database user set in a variable (terraform.tvars). It defaults to "metabase" but can be changed.
- I do encrypt the database user string, store in AWS Secrets Manager and have it injected into the task. This is done as more of an example of how we may want to treat the username in a multi-tenant environment more than being particularly useful for this example 


# Usage

1. `terraform init`
2. `terraform apply`

This will start to bring things up.

3. remember to run `terraform destroy` when you are done!`

# More Notes / Issues 
- If you receive an error about reading the secrets when running apply/destroy, it seems to be just a race condition. Adding an depends_on block to the params seemed to have little to no effect. However, just repeat the apply/destroy and it will resolve.
- Once the infrastructure is done applying, you will want to look at the "mde_mb" ECS Cluster in the AWS Management Console. Selecting the "web_ui" Service makes it really easy to see the logs in the "Logs" tab. 
- We can check the logs to prove that the Secrets are getting correctly stored/read since metabase will log if the database connection validates or not.
- Unfortunately, this is the only way to currently prove this, since the metabase container eventually exits (code 1) while trying to run migrations.
- I tried using a regular old rds instance instead of the cluster, to rule out the problem coming from usage of the serverless aurora flavor of postgres, however it failed at the same spot.
- I did discover that from the postres logs that postgres sees the issue as the client is closing the connection prematurely, which is probably due to the container unexpectedly exiting 
- I considered the issue may be related to using Fargate tasks and/or the use of the awsvpc network mode, however from looking at the web it seems this has worked in the past from what I can tell. 
- I tried various metabase release tags in addition to latest, which did alter how far along the metabase initialization would go before exiting, but I could not fully solve the issue.
- I tried different values for java heap size, task cpu, task mem (sane in relation to each other). This had no affect on the error, so I do not think resource settings such as those are involved in the error.
- Ultimately it really feels like a problem in the specific release tags I tried, but I stopped wasting time on this as the main purpose of the example is proven... the container connects to the db correctly using the secrets. 
- I am so bothered at not solving this part!

# Time Transparency
- The goal was 3 hours. 
- I was able to get things working just about as good as they are now in roughly 3 hours total time, except I neglected the README file at that point. 
- I spent roughly another hour on documenting, exceeding the time goal significantly.
_ I was super bothered by not having metabase up and running and decided to sleep on it, to see if I had any bright ideas. Had several which I tried out today. 
- Those attempts were not a great use of time though since they didn't pan out and ultimately I spent more time on this today just trying to debug.
- I then wanted to at least flesh out the docs a little more to cover some detailing of the things I tried.  
