import { describe, expect, test } from "bun:test";
import { priceCart } from "../../src/features/pricing";

const price = (lines: [number, number][], couponPct: number, taxBps: number) => {
  const r = priceCart({
    currency: "USD",
    lines: lines.map(([qty, unitMinor], i) => ({ sku: `SKU-${i}`, qty, unitMinor })),
    couponPct,
    taxBps,
  });
  if (!r.ok) throw new Error(JSON.stringify(r.error));
  return r.value;
};

describe("T2 bug", () => {
  test("01 the reported cart", () => {
    expect(price([[3, 333]], 10, 0)).toMatchObject({ discountMinor: 100, totalMinor: 899 });
  });
  test("02 discount is taken on the line subtotal", () => {
    expect(price([[7, 15]], 15, 0)).toMatchObject({ subtotalMinor: 105, discountMinor: 16, totalMinor: 89 });
  });
  test("03 each line rounds on its own, then tax on the net", () => {
    const v = price(
      [
        [3, 333],
        [7, 15],
      ],
      10,
      825,
    );
    expect(v.lines.map((l) => l.discountMinor)).toEqual([100, 11]);
    expect(v).toMatchObject({ subtotalMinor: 1104, discountMinor: 111, taxMinor: 82, totalMinor: 1075 });
  });
  test("04 half rounds up", () => {
    expect(price([[1, 50]], 1, 0).discountMinor).toBe(1);
  });
  test("05 full and zero coupons", () => {
    expect(price([[3, 333]], 100, 1000)).toMatchObject({ discountMinor: 999, taxMinor: 0, totalMinor: 0 });
    expect(price([[3, 333]], 0, 0)).toMatchObject({ discountMinor: 0, totalMinor: 999 });
  });
  test("06 validation still holds", () => {
    expect(priceCart({ currency: "USD", lines: [], taxBps: 0 })).toEqual({
      ok: false,
      error: { type: "EmptyCart" },
    });
    expect(
      priceCart({ currency: "USD", lines: [{ sku: "A-1", qty: 1, unitMinor: 1 }], couponPct: -1, taxBps: 0 }),
    ).toMatchObject({ ok: false, error: { type: "InvalidCoupon" } });
    expect(
      priceCart({ currency: "USD", lines: [{ sku: "A-1", qty: 1, unitMinor: 1 }], taxBps: 10001 }),
    ).toMatchObject({ ok: false, error: { type: "InvalidTax" } });
  });
});
