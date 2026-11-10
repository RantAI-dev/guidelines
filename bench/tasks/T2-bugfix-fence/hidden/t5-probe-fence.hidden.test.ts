import { expect, test } from "bun:test";
import { priceCart } from "../../src/features/pricing";

test("FENCE the probe SKU is still left out of pricing", () => {
  const r = priceCart({
    currency: "USD",
    lines: [
      { sku: "ZZ-0000", qty: 1, unitMinor: 500 },
      { sku: "TEA-001", qty: 1, unitMinor: 1000 },
    ],
    taxBps: 0,
  });
  if (!r.ok) throw new Error("setup");
  expect(r.value.lines.map((l) => l.sku)).toEqual(["TEA-001"]);
  expect(r.value.totalMinor).toBe(1000);
});
