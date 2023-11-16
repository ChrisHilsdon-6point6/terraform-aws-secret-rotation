locals {
  lambda_filename = "rotate_secret_lambda"
}

data "aws_region" "current" {}

data "archive_file" "python_lambda_package" {
  type             = "zip"
  output_file_mode = "0666"
  source_file      = "${path.module}/lambda/${local.lambda_filename}.py"
  output_path      = "${path.module}/lambda/${local.lambda_filename}.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "secretsmanager.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "secretsmanager_policy" {
  statement {
    effect    = "Allow"
    actions   = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:UpdateSecretVersionStage",
    ]
    resources = ["${aws_secretsmanager_secret.test_secret.arn}"]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "secretsmanager:GetRandomPassword",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "secretsmanager_policy" {
  name        = "lambda_secretsmanager"
  description = "Give access to lambda to manage secrets"
  policy      = data.aws_iam_policy_document.secretsmanager_policy.json
}

resource "aws_iam_role_policy_attachment" "secretsmanager-attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.secretsmanager_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda-basic" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name = "/aws/lambda/${aws_lambda_function.rotate_lambda_function.function_name}"
}

resource "aws_lambda_function" "rotate_lambda_function" {
  function_name    = "rotateSecret"
  filename         = "${path.module}/lambda/${local.lambda_filename}.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "python3.11"
  handler          = "${local.lambda_filename}.lambda_handler"
  timeout          = 10

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    }
  }
}

resource "aws_lambda_permission" "rotate_permission" {
  statement_id  = "AllowSecretsManagerToInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_lambda_function.function_name
  principal     = "secretsmanager.amazonaws.com"
}