// Public behaviour the mobile app builds against. Owned by the product owner.
// Do not edit without their sign-off (AGENTS.md rule 3).
import { describe, expect, test } from "bun:test";
import type { Order } from "../../src/contracts";
import { cancelOrder, createInMemoryOrderStore } from "../../src/features/orders";

const order = (id: string, status: Order["status"]): Order =>
  ({
    id,
    customerName: "Ada",
    createdAt: "2026-01-05T10:00:00.000Z",
    status,
    currency: "USD",
    lines: [{ sku: "TEA-001", description: "Green tea", qty: 2, unitMinor: 450 }],
  }) as Order;

describe("orders contract: cancel", () => {
  test("a pending order is cancelled and saved", () => {
    const store = createInMemoryOrderStore([order("ord_aaaaaa", "pending")]);
    const result = cancelOrder("ord_aaaaaa", { store });
    expect(result).toMatchObject({ ok: true, value: { id: "ord_aaaaaa", status: "cancelled" } });
    expect(store.list()[0]?.status).toBe("cancelled");
  });

  test("a shipped order cannot be cancelled", () => {
    const store = createInMemoryOrderStore([order("ord_bbbbbb", "shipped")]);
    expect(cancelOrder("ord_bbbbbb", { store })).toEqual({
      ok: false,
      error: { type: "NotCancellable", reason: "shipped", id: "ord_bbbbbb" },
    });
    expect(store.list()[0]?.status).toBe("shipped");
  });

  test("an unknown order is reported", () => {
    expect(cancelOrder("ord_zzzzzz", { store: createInMemoryOrderStore() })).toEqual({
      ok: false,
      error: { type: "OrderNotFound", id: "ord_zzzzzz" },
    });
  });
});
