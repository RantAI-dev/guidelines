import { describe, expect, test } from "bun:test";
import type { Order } from "../../contracts";
import { createInMemoryOrderStore } from "../orders";
import { exportInvoicesCsv } from "./index";

const order = (id: string, over: Record<string, unknown> = {}): Order =>
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

describe("exportInvoicesCsv input handling", () => {
  test("empty selection", () => {
    expect(run([], [])).toEqual({ ok: false, error: { type: "EmptySelection" } });
  });
  test("invalid id", () => {
    expect(run(["nope"], [])).toEqual({ ok: false, error: { type: "InvalidOrderId", value: "nope" } });
  });
  test("unknown id", () => {
    expect(run(["ord_zzzzzz"], [])).toEqual({
      ok: false,
      error: { type: "OrderNotFound", id: "ord_zzzzzz" },
    });
  });
  test("duplicates export once", () => {
    const r = run(["ord_aaaaaa", "ord_aaaaaa"], [order("ord_aaaaaa")]);
    expect(r.ok && r.value.split("\r\n").filter((l) => l.startsWith("ord_"))).toHaveLength(1);
  });
  test("cancelled orders are left out", () => {
    const r = run(
      ["ord_aaaaaa", "ord_bbbbbb"],
      [order("ord_aaaaaa"), order("ord_bbbbbb", { status: "cancelled" })],
    );
    expect(r.ok && r.value.includes("ord_bbbbbb")).toBe(false);
  });
  test("only cancelled orders", () => {
    expect(run(["ord_bbbbbb"], [order("ord_bbbbbb", { status: "cancelled" })])).toEqual({
      ok: false,
      error: { type: "NothingToExport" },
    });
  });
  test("mixed currencies are sorted", () => {
    expect(
      run(
        ["ord_aaaaaa", "ord_bbbbbb"],
        [order("ord_aaaaaa"), order("ord_bbbbbb", { currency: "JPY" })],
      ),
    ).toEqual({ ok: false, error: { type: "MixedCurrencies", currencies: ["JPY", "USD"] } });
  });
});

describe("exportInvoicesCsv output", () => {
  test("one order, exact document", () => {
    const r = run(["ord_aaaaaa"], [order("ord_aaaaaa")]);
    expect(r).toEqual({
      ok: true,
      value:
        "order_id,created_at,customer,sku,description,qty,unit_price,line_total\r\n" +
        "ord_aaaaaa,2026-01-05T10:00:00.000Z,Ada,TEA-001,Green tea,2,4.50,9.00\r\n" +
        "TOTAL,,,,,2,,9.00\r\n",
    });
  });
  test("orders are sorted by createdAt", () => {
    const r = run(
      ["ord_bbbbbb", "ord_aaaaaa"],
      [
        order("ord_bbbbbb", { createdAt: "2026-02-01T00:00:00.000Z" }),
        order("ord_aaaaaa", { createdAt: "2026-01-01T00:00:00.000Z" }),
      ],
    );
    expect(r.ok && r.value.indexOf("ord_aaaaaa") < r.value.indexOf("ord_bbbbbb")).toBe(true);
  });
  test("fields with a comma or quote are quoted", () => {
    const r = run(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          customerName: "Lovelace, Ada",
          lines: [{ sku: "TEA-001", description: 'The "good" tea', qty: 1, unitMinor: 100 }],
        }),
      ],
    );
    expect(r.ok && r.value).toContain('"Lovelace, Ada"');
    expect(r.ok && r.value).toContain('"The ""good"" tea"');
  });
  test("formula guard", () => {
    for (const lead of ["=", "+", "-", "@"]) {
      const r = run(["ord_aaaaaa"], [order("ord_aaaaaa", { customerName: `${lead}cmd` })]);
      expect(r.ok && r.value).toContain(`,'${lead}cmd,`);
    }
  });
  test("money formats per currency", () => {
    const jpy = run(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          currency: "JPY",
          lines: [{ sku: "TEA-001", description: "Tea", qty: 3, unitMinor: 500 }],
        }),
      ],
    );
    expect(jpy.ok && jpy.value).toContain(",Tea,3,500,1500\r\n");
    const kwd = run(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          currency: "KWD",
          lines: [{ sku: "TEA-001", description: "Tea", qty: 1, unitMinor: 1500 }],
        }),
      ],
    );
    expect(kwd.ok && kwd.value).toContain(",Tea,1,1.500,1.500\r\n");
    const refund = run(
      ["ord_aaaaaa"],
      [
        order("ord_aaaaaa", {
          lines: [{ sku: "REFUND-1", description: "Refund", qty: 1, unitMinor: -5 }],
        }),
      ],
    );
    expect(refund.ok && refund.value).toContain(",Refund,1,-0.05,-0.05\r\n");
  });
});
