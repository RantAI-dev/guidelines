import { describe, expect, test } from "bun:test";
import type { Order } from "../../src/contracts";
import { exportInvoicesCsv } from "../../src/features/invoice-export";
import { createInMemoryOrderStore } from "../../src/features/orders";

type Line = { sku: string; description: string; qty: number; unitMinor: number };
const order = (
  id: string,
  over: Partial<Record<keyof Order, unknown>> & { lines?: Line[] } = {},
): Order =>
  ({
    id,
    customerName: "Ada",
    createdAt: "2026-01-05T10:00:00.000Z",
    status: "paid",
    currency: "USD",
    lines: [{ sku: "TEA-001", description: "Green tea", qty: 2, unitMinor: 450 }],
    ...over,
  }) as unknown as Order;

const run = (ids: string[], orders: Order[]) =>
  exportInvoicesCsv(ids, { store: createInMemoryOrderStore(orders) });
const csv = (ids: string[], orders: Order[]): string => {
  const r = run(ids, orders);
  if (!r.ok) throw new Error(`expected ok, got ${JSON.stringify(r.error)}`);
  return r.value;
};
const HEADER = "order_id,created_at,customer,sku,description,qty,unit_price,line_total";

describe("T1 input handling", () => {
  test("01 empty selection", () => {
    expect(run([], [])).toEqual({ ok: false, error: { type: "EmptySelection" } });
  });
  test("02 invalid id wins over an earlier unknown id", () => {
    expect(run(["ord_missing1", "nope"], [])).toEqual({
      ok: false,
      error: { type: "InvalidOrderId", value: "nope" },
    });
  });
  test("03 first invalid id is the one reported", () => {
    expect(run(["bad one", "ORD_X"], [])).toEqual({
      ok: false,
      error: { type: "InvalidOrderId", value: "bad one" },
    });
  });
  test("04 first unknown id in input order", () => {
    expect(run(["ord_aaaaaa", "ord_zzzzzz", "ord_yyyyyy"], [order("ord_aaaaaa")])).toEqual({
      ok: false,
      error: { type: "OrderNotFound", id: "ord_zzzzzz" },
    });
  });
  test("05 duplicate ids export once", () => {
    const out = csv(["ord_aaaaaa", "ord_aaaaaa"], [order("ord_aaaaaa")]);
    expect(out.split("\r\n").filter((l) => l.startsWith("ord_aaaaaa"))).toHaveLength(1);
    expect(out).toContain("TOTAL,,,,,2,,9.00");
  });
  test("06 cancelled orders are left out", () => {
    const out = csv(
      ["ord_aaaaaa", "ord_bbbbbb"],
      [order("ord_aaaaaa"), order("ord_bbbbbb", { status: "cancelled" })],
    );
    expect(out).not.toContain("ord_bbbbbb");
  });
  test("07 only cancelled orders", () => {
    expect(run(["ord_bbbbbb"], [order("ord_bbbbbb", { status: "cancelled" })])).toEqual({
      ok: false,
      error: { type: "NothingToExport" },
    });
  });
  test("08 mixed currencies, sorted, no repeats", () => {
    const r = run(
      ["ord_aaaaaa", "ord_bbbbbb", "ord_cccccc"],
      [
        order("ord_aaaaaa", { currency: "USD" }),
        order("ord_bbbbbb", { currency: "JPY" }),
        order("ord_cccccc", { currency: "USD" }),
      ],
    );
    expect(r).toEqual({ ok: false, error: { type: "MixedCurrencies", currencies: ["JPY", "USD"] } });
  });
  test("09 a cancelled order's currency does not count", () => {
    const r = run(
      ["ord_aaaaaa", "ord_bbbbbb"],
      [order("ord_aaaaaa"), order("ord_bbbbbb", { currency: "JPY", status: "cancelled" })],
    );
    expect(r.ok).toBe(true);
  });
  test("10 does not write to the store", () => {
    const store = createInMemoryOrderStore([order("ord_aaaaaa")]);
    const before = JSON.stringify(store.list());
    exportInvoicesCsv(["ord_aaaaaa"], { store });
    expect(JSON.stringify(store.list())).toBe(before);
  });
});

describe("T1 output", () => {
  test("11 exact document for one order", () => {
    expect(csv(["ord_aaaaaa"], [order("ord_aaaaaa")])).toBe(
      `${HEADER}\r\nord_aaaaaa,2026-01-05T10:00:00.000Z,Ada,TEA-001,Green tea,2,4.50,9.00\r\nTOTAL,,,,,2,,9.00\r\n`,
    );
  });
  test("12 orders sorted by createdAt then id, lines keep their order", () => {
    const out = csv(
      ["ord_cccccc", "ord_bbbbbb", "ord_aaaaaa"],
      [
        order("ord_cccccc", { createdAt: "2026-01-01T00:00:00.000Z" }),
        order("ord_bbbbbb", {
          createdAt: "2026-02-01T00:00:00.000Z",
          lines: [
            { sku: "ZZZ-9", description: "last sku first", qty: 1, unitMinor: 100 },
            { sku: "AAA-1", description: "first sku last", qty: 1, unitMinor: 100 },
          ],
        }),
        order("ord_aaaaaa", { createdAt: "2026-02-01T00:00:00.000Z" }),
      ],
    );
    const firstCols = out.split("\r\n").slice(1, 5).map((l) => l.split(",")[0]);
    expect(firstCols).toEqual(["ord_cccccc", "ord_aaaaaa", "ord_bbbbbb", "ord_bbbbbb"]);
    expect(out.indexOf("ZZZ-9")).toBeLessThan(out.indexOf("AAA-1"));
  });
  test("13 every row ends with CRLF and there are no bare LFs", () => {
    const out = csv(["ord_aaaaaa"], [order("ord_aaaaaa")]);
    expect(out.endsWith("\r\n")).toBe(true);
    expect(out.replaceAll("\r\n", "")).not.toContain("\n");
  });
  test("14 comma and quote are quoted, quote doubled", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          customerName: "Lovelace, Ada",
          lines: [{ sku: "TEA-001", description: 'The "good" tea', qty: 1, unitMinor: 100 }],
        }),
      ],
    );
    expect(out).toContain(',"Lovelace, Ada",');
    expect(out).toContain(',"The ""good"" tea",');
  });
  test("15 newline inside a field is quoted", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          lines: [{ sku: "TEA-001", description: "two\nlines", qty: 1, unitMinor: 100 }],
        }),
      ],
    );
    expect(out).toContain(',"two\nlines",');
  });
  test("16 formula guard on = + - @", () => {
    for (const lead of ["=", "+", "-", "@"]) {
      const out = csv(["ord_aaaaaa"], [order("ord_aaaaaa", { customerName: `${lead}cmd` })]);
      expect(out).toContain(`,'${lead}cmd,`);
    }
  });
  test("17 guard is applied before quoting", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          lines: [{ sku: "TEA-001", description: "=SUM(A1,B1)", qty: 1, unitMinor: 100 }],
        }),
      ],
    );
    expect(out).toContain(`,"'=SUM(A1,B1)",`);
  });
  test("18 negative money is not guarded and keeps its leading zero", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          lines: [{ sku: "REFUND-1", description: "Refund", qty: 1, unitMinor: -5 }],
        }),
      ],
    );
    expect(out).toContain(",Refund,1,-0.05,-0.05\r\n");
    expect(out).toContain("TOTAL,,,,,1,,-0.05\r\n");
  });
  test("19 JPY has no decimal point", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          currency: "JPY",
          lines: [{ sku: "TEA-001", description: "Tea", qty: 3, unitMinor: 500 }],
        }),
      ],
    );
    expect(out).toContain(",Tea,3,500,1500\r\n");
    expect(out).toContain("TOTAL,,,,,3,,1500\r\n");
  });
  test("20 KWD has three decimals", () => {
    const out = csv(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          currency: "KWD",
          lines: [{ sku: "TEA-001", description: "Tea", qty: 1, unitMinor: 5 }],
        }),
      ],
    );
    expect(out).toContain(",Tea,1,0.005,0.005\r\n");
  });
  test("21 no thousands separator, totals add up across orders and refunds", () => {
    const out = csv(
      ["ord_aaaaaa", "ord_bbbbbb"],
      [
        order("ord_aaaaaa", {
          lines: [{ sku: "BIG-1", description: "Machine", qty: 2, unitMinor: 123456 }],
        }),
        order("ord_bbbbbb", {
          createdAt: "2026-03-01T00:00:00.000Z",
          lines: [
            { sku: "REFUND-1", description: "Refund", qty: 1, unitMinor: -1234 },
            { sku: "FREE-1", description: "Sample", qty: 0, unitMinor: 999 },
          ],
        }),
      ],
    );
    expect(out).toContain(",Machine,2,1234.56,2469.12\r\n");
    expect(out).toContain(",Sample,0,9.99,0.00\r\n");
    expect(out).toContain("TOTAL,,,,,3,,2456.78\r\n");
  });
});
