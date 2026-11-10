import { type Order, OrderId, type Result, err, ok } from "../../contracts";
import type { OrderStore } from "./order-store";

export type CancelOrderError =
  | { readonly type: "InvalidOrderId"; readonly value: string }
  | { readonly type: "OrderNotFound"; readonly id: string }
  | { readonly type: "NotCancellable"; readonly reason: "shipped"; readonly id: string };

export function cancelOrder(
  rawId: string,
  deps: { readonly store: OrderStore },
): Result<Order, CancelOrderError> {
  const parsed = OrderId.safeParse(rawId);
  if (!parsed.success) return err({ type: "InvalidOrderId", value: rawId });
  const order = deps.store.get(parsed.data);
  if (!order) return err({ type: "OrderNotFound", id: parsed.data });
  if (order.status === "shipped") {
    return err({ type: "NotCancellable", reason: "shipped", id: parsed.data });
  }
  if (order.status === "cancelled") return ok(order);
  const cancelled: Order = { ...order, status: "cancelled" };
  deps.store.put(cancelled);
  return ok(cancelled);
}
