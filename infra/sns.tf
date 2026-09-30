resource "aws_sns_topic" "orders_events" {
    name = "${var.project}-${var.env}-orders-events"

    tags = {
        Service = "order-service"
    }
}

resource "aws_sns_topic" "payments_events" {
    name = "${var.project}-${var.env}-payments-events"

    tags = {
        Service = "payment-service"
    }
}

resource "aws_sns_topic" "inventory_events" {
    name = "${var.project}-${var.env}-inventory-events"

    tags = {
        Service = "inventory-service"
    }
}
