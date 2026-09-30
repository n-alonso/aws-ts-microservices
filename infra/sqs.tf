resource "aws_sqs_queue" "payment_dlq" {
    name = "${var.project}-${var.env}-payment-dlq"
    message_retention_seconds = 1209600 # 14 days, the maximum
    sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "payment" {
    name = "${var.project}-${var.env}-payment"
    message_retention_seconds = 345600 # 4 days
    # visibility_timeout >= 6x Lambda timeout
    visibility_timeout_seconds = 180 # 3 minutes
    sqs_managed_sse_enabled = true

    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.payment_dlq.arn
        maxReceiveCount = 3
    })

    tags = {
        Service = "payment-service"
    }
}

resource "aws_sqs_queue" "inventory_dlq" {
    name = "${var.project}-${var.env}-inventory-dlq"
    message_retention_seconds = 1209600 # 14 days
    sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "inventory" {
    name = "${var.project}-${var.env}-inventory"
    message_retention_seconds = 345600 # 4 days
    # visibility_timeout >= 6x Lambda timeout
    visibility_timeout_seconds = 180 # 3 minutes
    sqs_managed_sse_enabled = true

    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.inventory_dlq.arn
        maxReceiveCount = 3
    })

    tags = {
        Service = "inventory-service"
    }
}

resource "aws_sqs_queue" "order_dlq" {
  name = "${var.project}-${var.env}-order-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "order" {
  name = "${var.project}-${var.env}-order"
  message_retention_seconds = 345600 # 4 days
  # visibility_timeout >= 6x Lambda timeout
  visibility_timeout_seconds = 180 # 3 minutes
  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount = 3
  })

  tags = {
    Service = "order-service"
  }
}

resource "aws_sqs_queue" "notification_dlq" {
  name = "${var.project}-${var.env}-notification-dlq"
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue" "notification" {
  name = "${var.project}-${var.env}-notification"
  message_retention_seconds = 345600 # 4 days
  # visibility_timeout >= 6x Lambda timeout
  visibility_timeout_seconds = 180 # 3 minutes
  sqs_managed_sse_enabled = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq.arn
    maxReceiveCount = 3
  })

  tags = {
    Service = "notification-service"
  }
}
