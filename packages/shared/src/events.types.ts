import {
    OrderPlacedData,
    OrderConfirmedData,
    OrderCancelledData,
    PaymentCapturedData,
    PaymentFailedData,
    InventoryReservedData,
    InventoryRejectedData
} from "./payloads.types";

type Envelope<TType extends string, TData> = {
    eventId: string; // UUID
    eventType: TType;
    occurredAt: string;
    version: number;
    source: string;
    correlationId: string;
    data: TData;
};

export type OrderPlacedEvent = Envelope<"OrderPlaced", OrderPlacedData>;
export type OrderConfirmedEvent = Envelope<"OrderConfirmed", OrderConfirmedData>;
export type OrderCancelledEvent = Envelope<"OrderCancelled", OrderCancelledData>;

export type PaymentCapturedEvent = Envelope<"PaymentCaptured", PaymentCapturedData>;
export type PaymentFailedEvent = Envelope<"PaymentFailed", PaymentFailedData>;

export type InventoryReservedEvent = Envelope<"InventoryReserved", InventoryReservedData>;
export type InventoryRejectedEvent = Envelope<"InventoryRejected", InventoryRejectedData>;

export type DomainEvent = OrderPlacedEvent 
    | OrderConfirmedEvent
    | OrderCancelledEvent
    | PaymentCapturedEvent
    | PaymentFailedEvent
    | InventoryReservedEvent
    | InventoryRejectedEvent;

export type EventType = DomainEvent["eventType"];
