variable "cluster_family" {
  type        = string
  description = "The DB cluster parameter group family"
  validation {
    condition = contains([
      "aurora-postgresql15",
      "aurora-postgresql16",
      "aurora-postgresql17",
    ], var.cluster_family)
    error_message = "Cluster family must be a valid Aurora PostgreSQL family."
  }
}

variable "instance_type" {
  type        = string
  default     = "db.serverless"
  description = "The instance type of the cluster. Defaults ot serverless."
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
  description = "Name of the database to create"
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
  description = "Maximum Aurora capacity unit for serverless cluster"
}

variable "min_capacity" {
  type        = number
  description = "Minimum Aurora capacity unit for serverless cluster"
}

variable "seconds_until_auto_pause" {
  type        = number
  description = "Seconds until the serverless cluster is automatically paused"
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