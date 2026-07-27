variable "cluster_family" {
  type        = string
  description = "The DB cluster parameter group family"
  validation {
    condition = contains([
      "aurora-postgresql15",
      "aurora-postgresql16",
      "aurora-postgresql17",
      "aurora-postgresql18",
    ], var.cluster_family)
    error_message = "Cluster family must be a valid Aurora PostgreSQL family."
  }
}

variable "cluster_parameter_group_name" {
  type        = string
  description = "Parameter group name to use for the RDS cluster."
  default     = null
}

variable "db_parameter_group_name" {
  type        = string
  description = "Parameter group name to use for the RDS instance."
  default     = null
}

variable "parameter_group_name_prefix_enabled" {
  type        = bool
  default     = false
  description = "Set to `true` to use `name_prefix` to name the cluster and database parameter groups. Set to `false` to use `name` instead"
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Set of log types to export to CloudWatch"
  default     = []
}

variable "instance_type" {
  type        = string
  default     = "db.serverless"
  description = "The instance type of the cluster. Use 'db.serverless' for Aurora Serverless v2, or a standard instance class (e.g. 'db.r8g.large') for provisioned."
}

variable "engine_mode" {
  type        = string
  default     = "provisioned"
  description = "The engine mode of the cluster. Defaults to provisioned."
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
  default     = "17.6"
}

variable "cluster_size" {
  type        = number
  description = "Size of the cluster"
}

variable "db_name" {
  type        = string
  description = "Name of the database to create. Required for standalone and primary clusters; must not be set for secondary clusters (replicated from primary)."
  default     = null
}

variable "db_port" {
  type        = number
  description = "Port on which the DB accepts connections"
  default     = 5432

  validation {
    condition     = var.db_port >= 1150 && var.db_port <= 65535
    error_message = "Database port must be between 1150 and 65535."
  }
}

variable "max_capacity" {
  type        = number
  description = "Maximum Aurora capacity unit (ACU) for Serverless v2. Required when instance_type is 'db.serverless', ignored otherwise."
  default     = null
}

variable "min_capacity" {
  type        = number
  description = "Minimum Aurora capacity unit (ACU) for Serverless v2. Required when instance_type is 'db.serverless', ignored otherwise."
  default     = null
}

variable "seconds_until_auto_pause" {
  type        = number
  description = "Seconds of inactivity before a Serverless v2 cluster auto-pauses. Only applies when min_capacity is 0."
  default     = 300
}

variable "iam_connect_readonly_user" {
  type        = string
  description = "Name of the user to allow read-only access to the cluster."
  default     = "data_platform_readonly"
}

variable "iam_connect_writer_user" {
  type        = string
  description = "Name of the user to allow write access to the cluster."
  default     = "data_platform_writer"
}

variable "iam_connect_migration_user" {
  type        = string
  description = "Name of the user to allow access to the cluster for migrations."
  default     = "data_platform_migration"
}

variable "iam_connect_extra_users" {
  type        = list(string)
  description = "List of additional users to allow RDS Connect access to the cluster."
  default     = []
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "List of security groups to be allowed to connect to the DB instance."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks allowed to access the cluster."
}

variable "subnets" {
  type        = list(string)
  description = "The Subnets to create the cluster in."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to create the cluster in."
}

variable "manage_admin_user_password" {
  type        = bool
  description = "Whether RDS should manage the admin user password in AWS Secrets Manager. Set to false to disable Secrets Manager integration (required for blue/green deployments)."
  default     = true
}

variable "admin_user" {
  type        = string
  description = "The name of the admin user for the cluster. Defaults to 'clusteradmin'."
  default     = "clusteradmin"
}

variable "admin_password" {
  type        = string
  description = "The password for the admin user. If manage_admin_user_password is true, this will be ignored and a random password will be generated and stored in AWS Secrets Manager."
  default     = null
  sensitive   = true
}

variable "cluster_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB cluster parameters to apply"
}

variable "instance_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB instance parameters to apply"
}

variable "instance_identifier_suffix" {
  type        = string
  default     = "1"
  nullable    = true
  description = <<-EOT
    The suffix to append to DB instance identifiers.
    If `null`, the module will generate a random suffix. If empty, no suffix will be appended.

    Stable suffix prevents random_pet regeneration on major version upgrades.
    We default to "1", as without this, changing cluster_family (a random_pet keeper) forces an instance
    rename → replacement → unnecessary writer failover on every major version bump.
    EOT
}

variable "cluster_role" {
  type        = string
  description = "Role of this cluster within a Global Aurora setup. Use 'standalone' for single-region clusters, 'primary' for the writer region of a global cluster, or 'secondary' for read replica regions."
  default     = "standalone"

  validation {
    condition     = contains(["standalone", "primary", "secondary"], var.cluster_role)
    error_message = "cluster_role must be one of: standalone, primary, secondary."
  }
}

variable "global_cluster_identifier" {
  type        = string
  description = "Identifier of the aws_rds_global_cluster this regional cluster belongs to. Required when cluster_role is 'primary' or 'secondary'."
  default     = null
}

########################################################################################################################
### Auto Scaling
########################################################################################################################

variable "enable_autoscaling" {
  type        = bool
  description = "Enable Application Auto Scaling for Aurora read replicas. Only valid for provisioned standalone or primary clusters."
  default     = false
}

variable "autoscaling_min_replicas" {
  type        = number
  description = "Minimum number of read replicas. Required when enable_autoscaling is true."
  default     = null
}

variable "autoscaling_max_replicas" {
  type        = number
  description = "Maximum number of read replicas. Required when enable_autoscaling is true."
  default     = null
}

variable "autoscaling_metric" {
  type        = string
  description = "Metric to scale on. One of 'cpu' or 'connections'."
  default     = "cpu"
  validation {
    condition     = contains(["cpu", "connections"], var.autoscaling_metric)
    error_message = "autoscaling_metric must be 'cpu' or 'connections'."
  }
}

variable "autoscaling_target_value" {
  type        = number
  description = "Target value for the scaling metric. Percentage (0-100) for 'cpu'; average count for 'connections'. Required when enable_autoscaling is true."
  default     = null
}

variable "autoscaling_scale_in_cooldown" {
  type        = number
  description = "Seconds to wait after a scale-in event before allowing another scale-in."
  default     = 300
}

variable "autoscaling_scale_out_cooldown" {
  type        = number
  description = "Seconds to wait after a scale-out event before allowing another scale-out."
  default     = 300
}