# terraform-infra

This repository contains the base Terraform code, including a structured setup with a few dummy modules.

## Guidelines

- **Do Not Delete Existing Files**: Retain the current structure and files, including dummy modules.
- **Modifications**: Feel free to:
  1. **Add**: Create new folders or files for additional modules.
  2. **Edit**: Modify contents of existing files like `dev.tfvars`, `main.tf`, or files in the root module as needed.

## Contribution

- Maintain the overall structure.
- Ensure new additions are consistent with the existing setup.
- Document significant changes for clarity.

## Workflow for Terraform State Management

This repository uses a dynamic approach to manage Terraform state files across different branches to prevent conflicts and ensure seamless collaboration.

### Key Points:

- **Dynamic Bucket Key with Account Number**: The Terraform state file's bucket key includes the AWS account number, making the YAML file dynamic and eliminating the need for manual adjustments per team.

- **Branch Name as State File Key**: We use the branch name as the state file key in the S3 bucket. This allows multiple users to run Terraform in the same AWS account from different branches without overwriting each other's state files.

- **Handling Resource Conflicts**: Since all changes are eventually merged into the main branch, running the same Terraform code from feature branches in the main branch would typically cause conflicts (e.g., a security group with the same name already exists). To avoid the cost of using different accounts or `.tfvars` for `main` branch, we adopt a functional workaround:

  - **Terraform Destroy on PR Approval**: we have a Terraform destroy job that triggers upon PR approval into the main branch. This ensures resources created in feature branches are destroyed before being applied in the main branch, preventing conflicts. The workflow for this can be found in `.github/workflows/terraform-destroy-dev.yaml`

### Workflow Overview:

1. **Terraform Apply** in `feature/x` branch *when a commit is pushed.*
2. **Terraform Destroy** in `feature/x` branch *when a PR from `feature-x` to `main` branch is approved.*
3. **Terraform Apply** in `main` branch *after PR merge.*

This approach ensures efficient resource management and conflict resolution in a multi-branch, multi-user Terraform environment.
