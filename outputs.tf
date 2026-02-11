output "endpoint" {
  value = module.rds_cluster_aurora_postgres.endpoint
}

output "read_only_endpoint" {
  value = module.rds_cluster_aurora_postgres.reader_endpoint
}

output "cluster_resource_id" {
  value       = module.rds_cluster_aurora_postgres.cluster_resource_id
  description = "The resource ID of the RDS cluster"
}

output "admin_user_secret" {
  value       = module.rds_cluster_aurora_postgres.admin_user_secret
  description = "The Secrets Manager secret including the admin user credentials"
}

output "iam_connect_user_policies" {
  value = aws_iam_policy.rds_user_connect_policy
}

output "env_variables" {
  value = [
    {
      name  = "POSTGRES_DATABASE"
      value = "data_platform"
    },
    {
      name  = "POSTGRES_PORT"
      value = "5432"
    },
    {
      name  = "POSTGRES_READ_ONLY_HOST"
      value = module.rds_cluster_aurora_postgres.reader_endpoint
    },
    {
      name  = "POSTGRES_READ_ONLY_USER"
      value = "data_platform_readonly"
    },
    {
      name  = "POSTGRES_WRITER_HOST"
      value = module.rds_cluster_aurora_postgres.endpoint
    },
    {
      name  = "POSTGRES_WRITER_USER"
      value = "data_platform_app"
    }
  ]
}