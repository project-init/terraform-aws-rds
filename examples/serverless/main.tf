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

  environment    = "staging"
  cluster_family = "aurora-postgresql17"
  engine_version = "17.6"
  db_name        = "aurora"
  cluster_size   = 1

  min_capacity             = 0
  max_capacity             = 1.0
  seconds_until_auto_pause = 1800

  iam_connect_users = [
    "readonly",
    "app",
    "migrate",
  ]

  security_groups = [
    "security-group-1",
    "security-group-2"
  ]
}