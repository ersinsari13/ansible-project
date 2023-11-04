#! /bin/bash
aws --region=us-east-1 ssm get-parameters --names "vault_passwd" --query "Parameters[*].{Value:Value}" --output text

# Go to AWS console and Parameter Store sercice.Create parameter and add your vault password my password is "123"
# Lastly you add execıtable permision this file.