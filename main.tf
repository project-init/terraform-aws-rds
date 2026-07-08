data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

########################################################################################################################
### IAM (RDS Connect)
########################################################################################################################

locals {
  iam_connect_users = concat([var.iam_connect_readonly_user, var.iam_connect_writer_user, var.iam_connect_migration_user], var.iam_connect_extra_users)
}

check "validate_iam_connect_users" {
  assert {
    condition     = var.iam_connect_readonly_user != var.iam_connect_writer_user || var.iam_connect_writer_user != var.iam_connect_migration_user
    error_message = "The readonly, writer, and migration users are all set to the same value (`${var.iam_connect_readonly_user}`). This is not recommended."
  }
}

resource "aws_iam_policy" "rds_user_connect_policy" {
  for_each = toset(local.iam_connect_users)

  name        = "${module.this.id}-rds-${each.key}-connect"
  description = "Grants rds-db:connect permission to use the PostgreSQL ${each.key} iam authentication."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "rds-db:connect",
        Resource = [
          "arn:aws:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${module.rds_cluster_aurora_postgres.cluster_resource_id}/${each.key}",
        ],
      },
    ],
  })
}

########################################################################################################################
### RDS
########################################################################################################################

module "rds_cluster_aurora_postgres" {
  source  = "cloudposse/rds-cluster/aws"
  version = "2.6.0"

  context = var.context

  instance_type       = var.instance_type
  engine              = "aurora-postgresql"
  engine_mode         = var.engine_mode
  cluster_family      = var.cluster_family
  engine_version      = var.engine_version
  cluster_size        = var.cluster_size
  storage_encrypted   = true
  deletion_protection = true

  db_name = var.db_name
  db_port = var.db_port
  vpc_id  = var.vpc_id
  subnets = var.subnets

  # RDS will manage admin credentials in Secrets Manager
  manage_admin_user_password          = var.manage_admin_user_password
  admin_user                          = "clusteradmin"
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration = {
    max_capacity             = var.max_capacity
    min_capacity             = var.min_capacity
    seconds_until_auto_pause = var.seconds_until_auto_pause
  }

  security_groups     = var.security_groups
  allowed_cidr_blocks = var.allowed_cidr_blocks

  rds_cluster_parameter_group_name = var.cluster_parameter_group_name
  enabled_cloudwatch_logs_exports  = var.enabled_cloudwatch_logs_exports
}
