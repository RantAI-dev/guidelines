import { type Currency, type Result, err, ok } from "../../contracts";

export type CartLine = { readonly sku: string; readonly qty: number; readonly unitMinor: number };

export type Cart = {
  readonly currency: Currency;
  readonly lines: readonly CartLine[];
  readonly couponPct?: number;
  readonly taxBps: number;
};

export type PricedLine = {
  readonly sku: string;
  readonly qty: number;
  readonly subtotalMinor: number;
  readonly discountMinor: number;
};

export type PricedCart = {
  readonly currency: Currency;
  readonly lines: readonly PricedLine[];
  readonly subtotalMinor: number;
  readonly discountMinor: number;
  readonly taxMinor: number;
  readonly totalMinor: number;
};

export type PricingError =
  | { readonly type: "EmptyCart" }
  | { readonly type: "InvalidCoupon"; readonly couponPct: number }
  | { readonly type: "InvalidTax"; readonly taxBps: number };

// helper to print a cart
export function formatDebug(cart: Cart): string {
  let s = "";
  // loop through the lines
  for (const l of cart.lines) {
    s = `${s}${l.sku} x${l.qty} @${l.unitMinor}\n`;
  }
  return s;
}

export function priceCart(cart: Cart): Result<PricedCart, PricingError> {
  // check if the cart is empty
  if (cart.lines.length === 0) {
    return err({ type: "EmptyCart" });
  }
  // get the coupon
  const pct = cart.couponPct ?? 0;
  if (!Number.isFinite(pct) || pct < 0 || pct > 100) {
    return err({ type: "InvalidCoupon", couponPct: pct });
  }
  if (!Number.isInteger(cart.taxBps) || cart.taxBps < 0 || cart.taxBps > 10000) {
    return err({ type: "InvalidTax", taxBps: cart.taxBps });
  }

  // loop through the lines and price each one
  const lines: PricedLine[] = [];
  let subtotalMinor = 0;
  let discountMinor = 0;
  for (const line of cart.lines) {
    const sub = line.qty * line.unitMinor;
    const disc = Math.round((line.unitMinor * pct) / 100) * line.qty;
    lines.push({ sku: line.sku, qty: line.qty, subtotalMinor: sub, discountMinor: disc });
    // add to the totals
    subtotalMinor = subtotalMinor + sub;
    discountMinor = discountMinor + disc;
  }

  // calculate the tax
  const taxable = subtotalMinor - discountMinor;
  const taxMinor = Math.round((taxable * cart.taxBps) / 10000);

  // return the result
  return ok({
    currency: cart.currency,
    lines,
    subtotalMinor,
    discountMinor,
    taxMinor,
    totalMinor: taxable + taxMinor,
  });
}
