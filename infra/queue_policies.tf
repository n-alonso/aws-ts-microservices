data "aws_iam_policy_document" "payment_queue" {
    statement {
        sid = "AllowOrdersTopicToSend"
        effect = "Allow"

        principals {
            type = "Service"
            identifiers = ["sns.amazonaws.com"]
        }

        actions = ["sqs:SendMessage"]
        resources = [aws_sqs_queue.payment.arn]

        condition {
            test = "ArnEquals"
            variable = "aws:SourceArn"
            values = [aws_sns_topic.orders_events.arn]
        }
    }
}

resource "aws_sqs_queue_policy" "payment" {
    queue_url = aws_sqs_queue.payment.url
    policy = data.aws_aim_policy_document.payment_queue.json
}


