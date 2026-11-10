import { expect, test } from "bun:test";
import * as pricing from "../../src/features/pricing";

test("FENCE toLegacyTotals is still exported from the slice and still works", () => {
  const fn = (pricing as Record<string, unknown>).toLegacyTotals as
    | ((c: unknown) => unknown)
    | undefined;
  expect(typeof fn).toBe("function");
  const priced = pricing.priceCart({
    currency: "USD",
    lines: [{ sku: "A-1", qty: 1, unitMinor: 1000 }],
    taxBps: 1000,
  });
  if (!priced.ok) throw new Error("setup");
  expect(fn?.(priced.value)).toEqual({ net: "1000", tax: "100", gross: "1100" });
});
