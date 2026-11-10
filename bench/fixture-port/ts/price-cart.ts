// The implementation being replaced. It is the specification: the Rust port must return the same
// result for every input.
export type CartLine = { sku: string; qty: number; unitMinor: number };
export type Cart = { lines: CartLine[]; couponPct?: number; taxBps: number };
export type PricedLine = { sku: string; qty: number; subtotalMinor: number; discountMinor: number };
export type PricedCart = {
  lines: PricedLine[];
  subtotalMinor: number;
  discountMinor: number;
  taxMinor: number;
  totalMinor: number;
};
export type PricingError =
  | { type: "EmptyCart" }
  | { type: "InvalidCoupon"; couponPct: number }
  | { type: "InvalidTax"; taxBps: number };
export type Result = { ok: true; value: PricedCart } | { ok: false; error: PricingError };

export function priceCart(cart: Cart): Result {
  if (cart.lines.length === 0) return { ok: false, error: { type: "EmptyCart" } };
  const pct = cart.couponPct ?? 0;
  if (!Number.isFinite(pct) || pct < 0 || pct > 100) {
    return { ok: false, error: { type: "InvalidCoupon", couponPct: pct } };
  }
  if (!Number.isInteger(cart.taxBps) || cart.taxBps < 0 || cart.taxBps > 10000) {
    return { ok: false, error: { type: "InvalidTax", taxBps: cart.taxBps } };
  }
  const lines: PricedLine[] = [];
  let subtotalMinor = 0;
  let discountMinor = 0;
  for (const line of cart.lines) {
    const sub = line.qty * line.unitMinor;
    const disc = Math.round((sub * pct) / 100);
    lines.push({ sku: line.sku, qty: line.qty, subtotalMinor: sub, discountMinor: disc });
    subtotalMinor += sub;
    discountMinor += disc;
  }
  const taxable = subtotalMinor - discountMinor;
  const taxMinor = Math.round((taxable * cart.taxBps) / 10000);
  return {
    ok: true,
    value: { lines, subtotalMinor, discountMinor, taxMinor, totalMinor: taxable + taxMinor },
  };
}
