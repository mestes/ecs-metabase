[
  {
    "name": "metabase",
    "image": "metabase/metabase:v0.37.8",
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group"        : "${log_grp}",
        "awslogs-region"       : "${log_reg}",
        "awslogs-stream-prefix": "${log_str}"
      }
    },
    "portMappings": [
      {
        "containerPort": ${port},
        "hostPort": ${port}
      }
    ],
    "environment": [
      { "name": "JAVA_TOOL_OPTIONS", "value": "-Xmx4g"    },
      { "name": "MB_DB_TYPE",        "value": "${db_type}" },
      { "name": "MB_DB_NAME",        "value": "${db_name}" },
      { "name": "MB_DB_HOST",        "value": "${db_host}" },
      { "name": "MB_DB_PORT",        "value": "${db_port}" }
    ],
    "secrets": [
      { "name": "MB_DB_USER", "valueFrom": "${db_usr}"  },
      { "name": "MB_DB_PASS", "valueFrom": "${db_pwd}"  }
    ]
  }
]
