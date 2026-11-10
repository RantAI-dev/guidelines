import { Order, type Result, err, ok } from "../../contracts";
import type { OrderStore } from "./order-store";

export type CreateOrderError =
  | { readonly type: "InvalidOrder"; readonly issues: readonly string[] }
  | { readonly type: "DuplicateOrder"; readonly id: string };

export function createOrder(
  input: unknown,
  deps: { readonly store: OrderStore },
): Result<Order, CreateOrderError> {
  const parsed = Order.safeParse(input);
  if (!parsed.success) {
    return err({
      type: "InvalidOrder",
      issues: parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`),
    });
  }
  if (deps.store.get(parsed.data.id)) {
    return err({ type: "DuplicateOrder", id: parsed.data.id });
  }
  deps.store.put(parsed.data);
  return ok(parsed.data);
}
