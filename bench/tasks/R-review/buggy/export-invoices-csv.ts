import {
  CURRENCY_MINOR_UNITS,
  type Currency,
  type Order,
  OrderId,
  type Result,
  err,
  ok,
} from "../../contracts";
import type { OrderStore } from "../orders";

export type ExportError =
  | { readonly type: "EmptySelection" }
  | { readonly type: "InvalidOrderId"; readonly value: string }
  | { readonly type: "OrderNotFound"; readonly id: string }
  | { readonly type: "NothingToExport" }
  | { readonly type: "MixedCurrencies"; readonly currencies: readonly Currency[] };

const HEADER = "order_id,created_at,customer,sku,description,qty,unit_price,line_total";

function formatMoney(minor: number, currency: Currency): string {
  const digits = CURRENCY_MINOR_UNITS[currency];
  const sign = minor < 0 ? "-" : "";
  const abs = Math.abs(minor)
    .toString()
    .padStart(digits + 1, "0");
  if (digits === 0) return `${sign}${abs}`;
  return `${sign}${abs.slice(0, -digits)}.${abs.slice(-digits)}`;
}

function quote(field: string): string {
  return /[",\r\n]/.test(field) ? `"${field.replaceAll('"', '""')}"` : field;
}

function guard(field: string): string {
  return /^[=+\-@]/.test(field) ? `'${field}` : field;
}

function text(field: string): string {
  return guard(quote(field));
}

export function exportInvoicesCsv(
  orderIds: readonly string[],
  deps: { readonly store: OrderStore },
): Result<string, ExportError> {
  if (orderIds.length === 0) return err({ type: "EmptySelection" });

  const seen = new Set<string>();
  const found: Order[] = [];
  for (const value of orderIds) {
    const parsed = OrderId.safeParse(value);
    if (!parsed.success) return err({ type: "InvalidOrderId", value });
    if (seen.has(parsed.data)) continue;
    seen.add(parsed.data);
    const order = deps.store.get(parsed.data);
    if (!order) return err({ type: "OrderNotFound", id: parsed.data });
    found.push(order);
  }

  const currencies = [...new Set(found.map((o) => o.currency))].sort();
  if (currencies.length > 1) return err({ type: "MixedCurrencies", currencies });

  const orders = found.filter((o) => o.status !== "cancelled");
  const currency = orders[0]?.currency;
  if (!currency) return err({ type: "NothingToExport" });

  orders.sort((a, b) => a.createdAt.localeCompare(b.createdAt));

  const rows = [HEADER];
  let qtySum = 0;
  let totalSum = 0;
  for (const order of orders) {
    for (const line of order.lines) {
      const lineTotal = line.qty * line.unitMinor;
      qtySum += line.qty;
      totalSum += lineTotal;
      rows.push(
        [
          quote(order.id),
          quote(order.createdAt),
          text(order.customerName),
          text(line.sku),
          text(line.description),
          String(line.qty),
          formatMoney(line.unitMinor, currency),
          formatMoney(lineTotal, currency),
        ].join(","),
      );
    }
  }
  rows.push(`TOTAL,,,,,${qtySum},,${formatMoney(totalSum, currency)}`);
  return ok(`${rows.join("\r\n")}\r\n`);
}
