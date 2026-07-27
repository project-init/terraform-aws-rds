# Global Aurora requires an aws_rds_global_cluster resource to be created first,
# then a primary regional cluster joined to it, and finally one or more secondary
# regional clusters pointing at the same global cluster identifier.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.81.0"
      configuration_aliases = [aws.primary, aws.secondary]
    }
  }
}

########################################################################################################################
### Providers — configure each region you want to deploy into
########################################################################################################################

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

########################################################################################################################
### Labels
########################################################################################################################

module "label_global" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name = "rds-global"
}

module "label_primary" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name = "rds-primary"
}

module "label_secondary" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name = "rds-secondary"
}

########################################################################################################################
### Global cluster — the control plane that spans both regions
########################################################################################################################

resource "aws_rds_global_cluster" "this" {
  provider = aws.primary

  global_cluster_identifier = module.label_global.id
  engine                    = "aurora-postgresql"
  engine_version            = "17.6"
  database_name             = "aurora"
  storage_encrypted         = true
  deletion_protection       = true
}

########################################################################################################################
### Primary cluster (us-east-1)
########################################################################################################################

module "rds_primary" {
  source = "project-init/rds/aws"
  # version = "vX.X.X"

  providers = {
    aws = aws.primary
  }

  context = module.label_primary.context

  cluster_role              = "primary"
  global_cluster_identifier = aws_rds_global_cluster.this.global_cluster_identifier

  cluster_family = "aurora-postgresql17"
  engine_version = "17.6"

  # db_name must match the database_name set on the global cluster
  db_name       = aws_rds_global_cluster.this.database_name
  cluster_size  = 2
  instance_type = "db.r8g.large"

  vpc_id  = "vpc-primary-id"
  subnets = ["subnet-primary-1", "subnet-primary-2"]

  security_groups = ["sg-primary"]

  iam_connect_readonly_user  = "readonly"
  iam_connect_writer_user    = "app"
  iam_connect_migration_user = "migrate"
}

########################################################################################################################
### KMS key — secondary region
# AWS requires an explicit KMS key for encrypted cross-region replicas. Create one
# in the secondary region and pass its ARN to the secondary cluster module.
########################################################################################################################

resource "aws_kms_key" "rds_secondary" {
  provider = aws.secondary

  description             = "KMS key for RDS secondary cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds_secondary" {
  provider = aws.secondary

  name          = "alias/${module.label_secondary.id}"
  target_key_id = aws_kms_key.rds_secondary.key_id
}

########################################################################################################################
### Secondary cluster (us-west-2)
# The secondary must be created after the primary is available. Use depends_on
# to enforce ordering, since there is no direct resource reference between them.
########################################################################################################################

module "rds_secondary" {
  source = "project-init/rds/aws"
  # version = "vX.X.X"

  providers = {
    aws = aws.secondary
  }

  context = module.label_secondary.context

  cluster_role              = "secondary"
  global_cluster_identifier = aws_rds_global_cluster.this.global_cluster_identifier

  cluster_family = "aurora-postgresql17"
  engine_version = "17.6"
  cluster_size   = 2
  instance_type  = "db.r8g.large"

  # Required for cross-region encrypted replicas — AWS rejects secondary clusters
  # with storage_encrypted=true unless a KMS key in the secondary region is explicit.
  kms_key_arn = aws_kms_key.rds_secondary.arn

  # db_name and manage_admin_user_password are intentionally omitted on secondaries —
  # both are replicated from the primary and the module enforces this via preconditions.

  vpc_id  = "vpc-secondary-id"
  subnets = ["subnet-secondary-1", "subnet-secondary-2"]

  security_groups = ["sg-secondary"]

  iam_connect_readonly_user  = "readonly"
  iam_connect_writer_user    = "app"
  iam_connect_migration_user = "migrate"

  depends_on = [module.rds_primary]
}