resource "aws_sns_topic_subscription" "orders_to_payment" {
    topic_arn = aws_sns_topic.orders_events.arn
    protocol = "sqs"
    endpoint = aws_sqs_queue.payment.arn

    raw_message_delivery = true
    
    filter_policy_scope = "MessageAttributes"
    filter_policy = jsonencode({
        eventType = ["OrderPlaced", "OrderCancelled"]
    })
}

resource "aws_sns_topic_subscription" "orders_to_inventory" {
    topic_arn = aws_sns_topic.orders_events.arn
    protocol = "sqs"
    endpoint = aws_sqs_queue.inventory.arn

    raw_message_delivery = true

    filter_policy_scope = "MessageAttributes"
    filter_policy = jsonencode({
        eventType = ["OrderPlaced", "OrderCancelled"]
    })
}

resource "aws_sns_topic_subscription" "payments_to_order" {
    topic_arn = aws_sns_topic.payments_events.arn
    protocol = "sqs"
    endpoint = aws_sqs_queue.order.arn

    raw_message_delivery = true

    filter_policy_scope = "MessageAttributes"
    filter_policy = jsonencode({
        eventType = ["PaymentCaptured", "PaymentFailed"]
    })
}

resource "aws_sns_topic_subscription" "inventory_to_order" {
    topic_arn = aws_sns_topic.inventory_events.arn
    protocol = "sqs"
    endpoint = aws_sqs_queue.order.arn

    raw_message_delivery = true

    filter_policy_scope = "MessageAttributes"
    filter_policy = jsonencode({
        eventType = ["InventoryReserved", "InventoryRejected"]
    })
}
