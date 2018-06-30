SHELL += -eu

BLUE	:= \033[0;34m
GREEN	:= \033[0;32m
RED   := \033[0;31m
NC    := \033[0m

export DIR_KEY_PAIR   := .keypair

export AWS_REGION           = us-west-2
export CLUSTER_NAME         = gpu-test

export AWS_EC2_KEY_NAME     ?= $(CLUSTER_NAME)-dcc
export AWS_EC2_KEY_PATH     := ${DIR_KEY_PAIR}/${AWS_EC2_KEY_NAME}.pem

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

## generate key-pair
all: create-keypair terraform-locals
	@echo "${GREEN}✓ keys generated ${NC}\n"

include ./makefiles/*.mk

## destroy and remove everything
clean:  delete-keypair

# Develop with tests running on code changes
.PHONY: terraform-locals
terraform-locals:
	@echo "locals {\n  key_name = \"${AWS_EC2_KEY_NAME}\"\n  region = \"${AWS_REGION}\"\n  env = \"${CLUSTER_NAME}\"\n  dcc_bucket = \"${CLUSTER_NAME}-dcc-jobs\"\n}\n" > "locals.tf"

.DEFAULT_GOAL := help
