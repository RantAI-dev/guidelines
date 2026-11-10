import { describe, expect, test } from "bun:test";
import { priceCart } from "./index";

describe("priceCart", () => {
  test("prices a single line with tax", () => {
    const result = priceCart({
      currency: "USD",
      lines: [{ sku: "TEA-001", qty: 1, unitMinor: 1000 }],
      taxBps: 1000,
    });
    expect(result).toMatchObject({
      ok: true,
      value: { subtotalMinor: 1000, discountMinor: 0, taxMinor: 100, totalMinor: 1100 },
    });
  });

  test("applies a coupon before tax", () => {
    const result = priceCart({
      currency: "USD",
      lines: [
        { sku: "TEA-001", qty: 1, unitMinor: 2000 },
        { sku: "CUP-002", qty: 1, unitMinor: 500 },
      ],
      couponPct: 20,
      taxBps: 1000,
    });
    expect(result).toMatchObject({
      ok: true,
      value: { subtotalMinor: 2500, discountMinor: 500, taxMinor: 200, totalMinor: 2200 },
    });
  });

  test("rejects an empty cart", () => {
    expect(priceCart({ currency: "USD", lines: [], taxBps: 0 })).toEqual({
      ok: false,
      error: { type: "EmptyCart" },
    });
  });

  test("rejects a coupon above 100", () => {
    const result = priceCart({
      currency: "USD",
      lines: [{ sku: "TEA-001", qty: 1, unitMinor: 100 }],
      couponPct: 120,
      taxBps: 0,
    });
    expect(result).toEqual({ ok: false, error: { type: "InvalidCoupon", couponPct: 120 } });
  });
});
