cluster_name = "eks-kadze-dev"
environment  = "dev"

# Fill in after running bootstrap:
#   cd bootstrap && terraform apply
#   Copy the gha_terraform_role_arn output here, and set it as IAM_ROLE
#   on the dev GitHub environment.
#
# Add your own IAM user/role ARN if you want kubectl access from your laptop.
admin_role_arns = [
  "arn:aws:iam::381492277294:role/gha-terraform-bootstrap-dev",
  "arn:aws:iam::381492277294:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_08cbdd74d1ed810f",
]
