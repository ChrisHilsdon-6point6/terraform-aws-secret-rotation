resource "aws_secretsmanager_secret" "test_secret" {
  name                    = "test_secret1"
  description             = "A test secret string"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "test_secret" {
  secret_id     = aws_secretsmanager_secret.test_secret.id
  secret_string = "test"
}

resource "aws_secretsmanager_secret_rotation" "test_secret_rotate" {
  secret_id           = aws_secretsmanager_secret.test_secret.id
  rotation_lambda_arn = aws_lambda_function.rotate_lambda_function.arn

  rotation_rules {
    schedule_expression = "cron(0 0/4 * * ? *)"
  }
}