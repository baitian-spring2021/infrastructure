# Infrastructure Setup with Terraform

### Pre-requisites
 * AWS CLI
 * Terraform
 * Approved SSL Certificate in Your AWS Certificate Manager (AWS CLI import command listed below, all files must be in pem format)
 ```sh
$ aws acm import-certificate --certificate fileb://{your certificate} \
    --certificate-chain fileb://{your certificate chain} \
    --private-key fileb://{your private key}
 ```

### Configuration

> Pre-requisites
> * AWS CLI
> * Terraform
> * Approved SSL Certificate in Your AWS Certificate Manager (AWS CLI import command listed below, all files must be in pem format)
$ aws acm import-certificate --certificate fileb://{your certificate} \
    --certificate-chain fileb://{your certificate chain} \
    --private-key fileb://{your private key}

1. Clone this repository.
```sh
$ git clone {repo link}
```
2. Set up the variables.tf file and configure the AWS credentials with AWS CLI. 
```sh
$ aws configure --profile {your profile}
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
