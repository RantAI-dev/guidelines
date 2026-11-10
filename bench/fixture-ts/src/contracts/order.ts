import { z } from "zod";
import { OrderId, Sku } from "./ids";
import { Currency, MinorAmount } from "./money";

export const OrderStatus = z.enum(["pending", "paid", "shipped", "cancelled"]);
export type OrderStatus = z.infer<typeof OrderStatus>;

export const OrderLine = z.object({
  sku: Sku,
  description: z.string(),
  qty: z.number().int().nonnegative(),
  // Negative for refund lines.
  unitMinor: MinorAmount,
});
export type OrderLine = z.infer<typeof OrderLine>;

export const Order = z.object({
  id: OrderId,
  customerName: z.string().min(1),
  createdAt: z.string().datetime(),
  status: OrderStatus,
  currency: Currency,
  lines: z.array(OrderLine).min(1),
});
export type Order = z.infer<typeof Order>;
