export type OrderItem = {
    sku: string;
    qty: number;
    unitPrice: string;
};

export type OrderPlacedData = {
    orderId: string;
    customerId: string;
    items: OrderItem[];
    totalAmount: string;
    currency: string;
};

export type OrderConfirmedData = {
    orderId: string;
};

export type OrderCancelledData = {
    orderId: string;
    reason: string;
};

export type PaymentCapturedData = {
    paymentId: string;
    orderId: string;
    totalAmount: string;
    currency: string;
};

export type PaymentFailedData = {
    paymentId: string;
    orderId: string;
    reason: string;
};

export type InventoryReservedData = {
    orderId: string;
    items: OrderItem[];
};

export type InventoryRejectedData = {
    orderId: string;
    reason: string;
    unavailableSkus: string[];
};
