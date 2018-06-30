Terraform infrastructure to develop and test GPU support.

Also doubles as a good development stack.

Everything is behind a private network in a VPC except the bastion. Hit the services via SSH tunnels (see below).

## Tasks

### Initialize the test stack

	make create-keypair
	git secret add .keypair/gpu-test-dcc.pem

The `git secret add` arg will depend on your exact key name.
Build the stack:

	terraform init
	terraform apply -auto-approve

### SSH Tunnels

Check kibana logs via an ssh tunnel (see terraform apply output).

Hit the remote server locally with an ssh tunnel (see terraform apply output).

### Develop and test code that touches GPU support

1. Write code
2. Change the **VERSION** in `Makefile` e.g. `0.4.4`
3. In the project root (not this dir): `make terraform-gpu-full-deploy`
