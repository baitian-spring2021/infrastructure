# Infrastructure Setup with Terraform

### Configuration

> Pre-requisites
> * AWS CLI
> * Terraform

1. Clone this repository.
```sh
$ git clone {repo link}
```
2. Set up the variables.tf file and configure the AWS credentials with AWS CLI. 
```sh
$ aws configure --profile {your profile name}
```
3. Initialize the working directory.
```sh
$ terraform init
```
4. Plan the execution.
```sh
$ terraform plan
```
5. Apply the resources to AWS cloud.
```sh
$ terraform apply -auto-approve
```
* To destroy the Terraform resources.
```sh
$ terraform destroy -auto-approve
```
