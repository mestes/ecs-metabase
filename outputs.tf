output "app_host" {
  value = join(":", [aws_lb.mde_mb.dns_name, var.port])
}

output "db_endpoint" {
  value = join(":", [aws_rds_cluster.pg.endpoint, aws_rds_cluster.pg.port] )
}

output "db_user" {
  value = data.aws_secretsmanager_secret_version.db_usr.secret_string
}

output "db_pass" {
  value = data.aws_secretsmanager_secret_version.db_pwd.secret_string
}
