import type { PricedCart } from "./price-cart";

export type LegacyTotals = { readonly net: string; readonly tax: string; readonly gross: string };

export function toLegacyTotals(cart: PricedCart): LegacyTotals {
  const net = cart.subtotalMinor - cart.discountMinor;
  return { net: String(net), tax: String(cart.taxMinor), gross: String(cart.totalMinor) };
}
