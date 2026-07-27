data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

########################################################################################################################
### IAM (RDS Connect)
########################################################################################################################

locals {
  iam_connect_users = concat([var.iam_connect_readonly_user, var.iam_connect_writer_user, var.iam_connect_migration_user], var.iam_connect_extra_users)

  is_serverless = var.instance_type == "db.serverless"

  serverlessv2_scaling_configuration = local.is_serverless ? {
    max_capacity             = var.max_capacity
    min_capacity             = var.min_capacity
    seconds_until_auto_pause = var.seconds_until_auto_pause
  } : null

  # Derive the underlying cluster_type expected by the cloudposse module.
  # standalone maps to "regional"; primary and secondary both join a global cluster.
  cluster_type = var.cluster_role == "standalone" ? "regional" : "global"

  # AWS rejects MasterUsername/MasterPassword on secondary cross-region clusters.
  admin_user     = var.cluster_role == "secondary" ? null : var.admin_user
  admin_password = var.cluster_role == "secondary" ? null : var.admin_password

  autoscaling_metric_type = {
    cpu         = "RDSReaderAverageCPUUtilization"
    connections = "RDSReaderAverageDatabaseConnections"
  }
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

resource "terraform_data" "serverless_capacity_required" {
  lifecycle {
    precondition {
      condition     = !local.is_serverless || (var.min_capacity != null && var.max_capacity != null)
      error_message = "min_capacity and max_capacity are required when instance_type is 'db.serverless'."
    }
  }
}

resource "terraform_data" "autoscaling_preconditions" {
  lifecycle {
    precondition {
      condition     = !var.enable_autoscaling || !local.is_serverless
      error_message = "enable_autoscaling cannot be used with db.serverless — use min_capacity/max_capacity for Serverless v2 scaling."
    }
    precondition {
      condition     = !var.enable_autoscaling || var.cluster_role != "secondary"
      error_message = "enable_autoscaling cannot be used on a secondary cluster."
    }
    precondition {
      condition = !var.enable_autoscaling || (
        var.autoscaling_min_replicas != null &&
        var.autoscaling_max_replicas != null &&
        var.autoscaling_target_value != null &&
        var.autoscaling_max_replicas > var.autoscaling_min_replicas
      )
      error_message = "autoscaling_min_replicas, autoscaling_max_replicas (must be > min), and autoscaling_target_value are all required when enable_autoscaling is true."
    }
  }
}

resource "terraform_data" "global_cluster_preconditions" {
  lifecycle {
    precondition {
      condition     = var.cluster_role == "standalone" || var.global_cluster_identifier != null
      error_message = "global_cluster_identifier is required when cluster_role is 'primary' or 'secondary'."
    }

    precondition {
      condition     = var.cluster_role != "secondary" || var.db_name == null
      error_message = "db_name must not be set on a secondary cluster — it is replicated from the primary."
    }

    precondition {
      condition     = var.cluster_role == "secondary" || var.db_name != null
      error_message = "db_name is required for standalone and primary clusters."
    }

    precondition {
      condition     = var.cluster_role != "secondary" || !var.manage_admin_user_password
      error_message = "manage_admin_user_password must be false on a secondary cluster — credentials are replicated from the primary."
    }
  }
}

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

  cluster_type              = local.cluster_type
  global_cluster_identifier = var.global_cluster_identifier == null ? "" : var.global_cluster_identifier

  db_name = var.db_name == null ? "" : var.db_name
  db_port = var.db_port
  vpc_id  = var.vpc_id
  subnets = var.subnets

  # RDS will manage admin credentials in Secrets Manager
  manage_admin_user_password          = var.manage_admin_user_password
  admin_user                          = local.admin_user
  admin_password                      = local.admin_password
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration = local.serverlessv2_scaling_configuration

  security_groups     = var.security_groups
  allowed_cidr_blocks = var.allowed_cidr_blocks

  rds_cluster_parameter_group_name    = var.cluster_parameter_group_name
  db_parameter_group_name             = var.db_parameter_group_name
  parameter_group_name_prefix_enabled = var.parameter_group_name_prefix_enabled
  cluster_parameters                  = var.cluster_parameters
  instance_parameters                 = var.instance_parameters

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  instance_identifier_suffix      = var.instance_identifier_suffix
}

########################################################################################################################
### Autoscaling
########################################################################################################################

resource "aws_appautoscaling_target" "read_replica" {
  count      = var.enable_autoscaling ? 1 : 0
  depends_on = [terraform_data.autoscaling_preconditions]

  service_namespace  = "rds"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  resource_id        = "cluster:${module.rds_cluster_aurora_postgres.cluster_identifier}"
  min_capacity       = var.autoscaling_min_replicas
  max_capacity       = var.autoscaling_max_replicas
}

resource "aws_appautoscaling_policy" "read_replica" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${module.this.id}-replica-autoscaling"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.read_replica[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.read_replica[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.read_replica[0].resource_id

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = local.autoscaling_metric_type[var.autoscaling_metric]
    }
    target_value       = var.autoscaling_target_value
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}
