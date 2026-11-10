import { describe, expect, test } from "bun:test";
import { createInMemoryOrderStore, createOrder } from "./index";

const valid = {
  id: "ord_abc123",
  customerName: "Ada",
  createdAt: "2026-01-05T10:00:00.000Z",
  status: "pending",
  currency: "USD",
  lines: [{ sku: "TEA-001", description: "Green tea", qty: 2, unitMinor: 450 }],
};

describe("createOrder", () => {
  test("stores a valid order", () => {
    const store = createInMemoryOrderStore();
    const result = createOrder(valid, { store });
    expect(result.ok).toBe(true);
    expect(store.list()).toHaveLength(1);
  });

  test("rejects a malformed id with the failing path", () => {
    const result = createOrder({ ...valid, id: "abc" }, { store: createInMemoryOrderStore() });
    expect(result).toMatchObject({ ok: false, error: { type: "InvalidOrder" } });
  });

  test("rejects a second order with the same id", () => {
    const store = createInMemoryOrderStore();
    createOrder(valid, { store });
    expect(createOrder(valid, { store })).toEqual({
      ok: false,
      error: { type: "DuplicateOrder", id: "ord_abc123" },
    });
  });
});
