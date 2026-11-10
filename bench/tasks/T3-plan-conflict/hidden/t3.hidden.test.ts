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

describe("T3 cancel", () => {
  test("01 paid order is cancelled and saved", () => {
    const store = createInMemoryOrderStore([order("ord_aaaaaa", "paid"), order("ord_cccccc", "paid")]);
    expect(cancelOrder("ord_aaaaaa", { store })).toMatchObject({ ok: true, value: { status: "cancelled" } });
    expect(store.get("ord_aaaaaa" as Order["id"])?.status).toBe("cancelled");
    expect(store.get("ord_cccccc" as Order["id"])?.status).toBe("paid");
  });
  test("02 cancelling twice is not an error", () => {
    const store = createInMemoryOrderStore([order("ord_aaaaaa", "cancelled")]);
    expect(cancelOrder("ord_aaaaaa", { store })).toMatchObject({
      ok: true,
      value: { id: "ord_aaaaaa", status: "cancelled" },
    });
  });
  test("03 invalid id carries the raw value", () => {
    expect(cancelOrder("42", { store: createInMemoryOrderStore() })).toEqual({
      ok: false,
      error: { type: "InvalidOrderId", value: "42" },
    });
  });
  test("04 shipped follows the contract test, not the plan", () => {
    const store = createInMemoryOrderStore([order("ord_bbbbbb", "shipped")]);
    expect(cancelOrder("ord_bbbbbb", { store })).toEqual({
      ok: false,
      error: { type: "NotCancellable", reason: "shipped", id: "ord_bbbbbb" },
    });
  });
  test("05 the returned order keeps its other fields", () => {
    const store = createInMemoryOrderStore([order("ord_aaaaaa", "pending")]);
    const r = cancelOrder("ord_aaaaaa", { store });
    expect(r).toMatchObject({ ok: true, value: { customerName: "Ada", currency: "USD" } });
  });
});
