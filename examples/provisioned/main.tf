module "label_rds" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  name = "rds"
}

module "rds" {
  source = "project-init/rds/aws"
  # Project Init recommends pinning every module to a specific version
  # version = "vX.X.X"

  context = module.label_rds.context

  cluster_family = "aurora-postgresql17"
  engine_version = "17.6"
  db_name        = "aurora"
  cluster_size   = 2

  # Provisioned instance class — min/max_capacity are not required when not using serverless
  instance_type = "db.r8g.large"

  iam_connect_readonly_user  = "readonly"
  iam_connect_writer_user    = "app"
  iam_connect_migration_user = "migrate"

  security_groups = [
    "security-group-1",
    "security-group-2",
  ]
}