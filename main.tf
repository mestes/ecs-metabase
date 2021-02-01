terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  ts_string     = formatdate("YYYY-MM-DD-hh-mm-ss",timestamp())
  final_snap_id = join("-",["mde","mb","final",local.ts_string])
}

resource "random_password" "gen_pwd" {
  length = 16
  special = false
}

resource "aws_vpc" "mde_mb" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "mde_mb"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mde_mb.id

  tags = {
    Name = "mde mb igw"
  }
}

resource "aws_subnet" "mde_mb1" {
  vpc_id            = aws_vpc.mde_mb.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = var.aws_zones[0]
  tags = {
    Name = "mde_mb1"
  }
}

resource "aws_subnet" "mde_mb2" {
  vpc_id            = aws_vpc.mde_mb.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.aws_zones[1]
  tags = {
    Name = "mde_mb2"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.mde_mb.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "mde_mb_rt"
  }
}

resource "aws_main_route_table_association" "mra" {
  vpc_id         = aws_vpc.mde_mb.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.mde_mb1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.mde_mb2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_eip" "s1" {
  vpc      = true
}

resource "aws_eip" "s2" {
  vpc      = true
}

resource "aws_nat_gateway" "ngw1" {
  allocation_id = aws_eip.s1.id
  subnet_id     = aws_subnet.mde_mb1.id

  tags = {
    Name = "MDE MB NAT 1"
  }
}

resource "aws_nat_gateway" "ngw2" {
  allocation_id = aws_eip.s2.id
  subnet_id     = aws_subnet.mde_mb2.id

  tags = {
    Name = "MDE MB NAT 2"
  }
}

resource "aws_security_group" "mde_mb" {
  name        = "allow_mb_inbound"
  description = "Allow inbound"
  vpc_id      = aws_vpc.mde_mb.id

  ingress {
    description = "allow connections"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mde_mb_allow"
  }
}


resource "aws_security_group" "pg" {
  name        = "allow_pg_inbound"
  description = "Allow inbound"
  vpc_id      = aws_vpc.mde_mb.id

  ingress {
    description = "allow connections"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mde_mb_pg_allow"
  }
}

resource "aws_ecs_cluster" "mde_mb" {
  name = "mde_mb"
}

resource "aws_lb_target_group" "mde_mb" {
  name        = "mde-mb-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.mde_mb.id
  deregistration_delay = 30
}

resource "aws_lb" "mde_mb" {
  name               = "mde-mb-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.mde_mb1.id, aws_subnet.mde_mb2.id]
  security_groups    = [aws_security_group.mde_mb.id]

  tags = {
    Name = "MDE MB ALB"
  }
}

resource "aws_lb_listener" "mde_mb" {
  load_balancer_arn = aws_lb.mde_mb.arn
  port              = var.port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mde_mb.arn
  }
}

resource "aws_ecs_service" "web_ui" {
  name             = "web_ui"
  cluster          = aws_ecs_cluster.mde_mb.id
  task_definition  = aws_ecs_task_definition.web_ui.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  health_check_grace_period_seconds = 300
  network_configuration {
    subnets          = [aws_subnet.mde_mb1.id, aws_subnet.mde_mb2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.mde_mb.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mde_mb.arn
    container_name   = "metabase"
    container_port   = var.port
  }

}

resource "aws_secretsmanager_secret" "db_usr" {
  name                    = "db_usr"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_usr" {
  secret_id     = aws_secretsmanager_secret.db_usr.id
  secret_string = var.db_usr
}

resource "aws_secretsmanager_secret" "db_pwd" {
  name                    = "db_pwd"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_pwd" {
  secret_id     = aws_secretsmanager_secret.db_pwd.id
  secret_string = random_password.gen_pwd.result
}

data "aws_secretsmanager_secret_version" "db_usr" {
  secret_id  = aws_secretsmanager_secret.db_usr.id
  depends_on = [aws_secretsmanager_secret_version.db_usr]
}

data "aws_secretsmanager_secret_version" "db_pwd" {
  secret_id  = aws_secretsmanager_secret.db_pwd.id
  depends_on = [aws_secretsmanager_secret_version.db_pwd]
}

resource "aws_cloudwatch_log_group" "pg" {
  name = "pg"
}

resource "aws_cloudwatch_log_stream" "pg" {
  name           = "pg"
  log_group_name = aws_cloudwatch_log_group.pg.name
}

data "template_file" "web_ui_tpl" {
  template = file("./web_ui.json.tpl")

  vars = {
    port    = var.port
    db_usr  = aws_secretsmanager_secret.db_usr.arn
    db_pwd  = aws_secretsmanager_secret.db_pwd.arn
    db_host = aws_rds_cluster.pg.endpoint
    db_port = aws_rds_cluster.pg.port
    db_type = "postgres"
    db_name = "metabase"
    log_grp = aws_cloudwatch_log_group.pg.name
    log_str = aws_cloudwatch_log_stream.pg.name,
    log_reg = var.aws_region
  }
}

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role_mde_mb" {
  name               = "ecs_task_role_mde_mb"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy" "sm" {
  name = "ecs-secretsmanager"
  role = aws_iam_role.ecs_task_role_mde_mb.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_secretsmanager_secret.db_pwd.arn}",
          "${aws_secretsmanager_secret.db_usr.arn}"
        ]
      }
    ]
  }
  EOF
}


data "aws_iam_policy" "ecs_task_exec" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy" "ssm_ro" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "rpa1" {
  role       = aws_iam_role.ecs_task_role_mde_mb.name
  policy_arn = data.aws_iam_policy.ecs_task_exec.arn
}

resource "aws_iam_role_policy_attachment" "rpa2" {
  role       = aws_iam_role.ecs_task_role_mde_mb.name
  policy_arn = data.aws_iam_policy.ssm_ro.arn
}

resource "aws_ecs_task_definition" "web_ui" {
  family                   = "web_ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  execution_role_arn       = aws_iam_role.ecs_task_role_mde_mb.arn
  container_definitions    = data.template_file.web_ui_tpl.rendered
}

resource "aws_db_subnet_group" "mde_mb" {
  name_prefix = "mde_mb_"
  subnet_ids  = [aws_subnet.mde_mb1.id, aws_subnet.mde_mb2.id]

  tags = {
    Name = "MDE MB DB subnet group"
  }
}

resource "aws_rds_cluster" "pg" {
  cluster_identifier        = "aurora-pg-mde-mb"
  engine                    = "aurora-postgresql"
  database_name             = "metabase"
  db_subnet_group_name      = aws_db_subnet_group.mde_mb.id
  master_username           = data.aws_secretsmanager_secret_version.db_usr.secret_string
  master_password           = data.aws_secretsmanager_secret_version.db_pwd.secret_string
  engine_mode               = "serverless"
  vpc_security_group_ids    = [aws_security_group.pg.id] 
  skip_final_snapshot       = true

  scaling_configuration {
    max_capacity             = 16
    min_capacity             = 4
  }
}

