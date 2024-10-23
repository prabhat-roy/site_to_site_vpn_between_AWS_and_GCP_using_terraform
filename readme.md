Site to site vpn between AWS and GCP using terraform.

Create a credential with Administrator Access in AWS and configure in cli to authenticate with AWS.

Create a key pair in AWS and add the file path in terraform.tfvars file (line number 7) to associate with ec2.

Create a service account in GCP and assign Compute Admin role, then create key and use that key to authenticate with GCP in terraform.tfvars file (line number 4).

Create a public and private keypair using ssh-keygen command and use the path in terraform.tfvars file (line number 15 & 16) to associate with vm.

Run terraform apply -auto-approve to create infrastructure in both AWS & GCP and login each vm to ping private ip of the other vm.


