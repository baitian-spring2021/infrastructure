# Infrastructure Setup with Terraform

### Prerequisites
- AWS CLI
- Terraform

### Setup
1. Clone this repository.
2. Go to the folder below.
```sh
$ cd /infrastructure/aws/terraform/application/module1/
```
3. Create terraform.tfvars configuration file and set the resource variables.
4. Configure the AWS credentials with AWS CLI.
```sh
$ aws configure --profile {your profile name}
```

### Execution
1. Initialize the working directory.
```sh
$ terraform init
```
2. Plan the execution.
```sh
$ terraform plan
```
3. Apply the resources to AWS cloud.
```sh
$ terraform apply -auto-approve
```
* To destrop the Terraform resources.
```sh
$ terraform destroy -auto-approve
```
