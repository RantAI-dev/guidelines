// Runs the old implementation on case lines and prints "case => result", one per line.
//   bun ts/oracle.ts cases/visible.txt          (re-derives the expected results)
//   echo 'tax=0;pct=10;A-1:3:333' | bun ts/oracle.ts
// Case line:   tax=<number>;pct=<number or empty>;<sku>:<qty>:<unitMinor>,<sku>:<qty>:<unitMinor>
// Result line: ok;sub=<n>;disc=<n>;tax=<n>;total=<n>;lines=<subtotal>:<discount>,...
//              err;EmptyCart | err;InvalidCoupon;<value> | err;InvalidTax;<value>
import { type Cart, priceCart } from "./price-cart";

function parse(line: string): Cart {
  const [tax = "", pct = "", items = ""] = line.split(";");
  const pctText = pct.replace(/^pct=/, "");
  const cart: Cart = {
    taxBps: Number(tax.replace(/^tax=/, "")),
    lines: items
      .split(",")
      .filter((s) => s.length > 0)
      .map((s) => {
        const [sku = "", qty = "", unit = ""] = s.split(":");
        return { sku, qty: Number(qty), unitMinor: Number(unit) };
      }),
  };
  if (pctText !== "") cart.couponPct = Number(pctText);
  return cart;
}

function format(cart: Cart): string {
  const r = priceCart(cart);
  if (!r.ok) {
    const e = r.error;
    if (e.type === "EmptyCart") return "err;EmptyCart";
    return e.type === "InvalidCoupon" ? `err;InvalidCoupon;${e.couponPct}` : `err;InvalidTax;${e.taxBps}`;
  }
  const v = r.value;
  const n = (x: number) => String(x === 0 ? 0 : x);
  const lines = v.lines.map((l) => `${n(l.subtotalMinor)}:${n(l.discountMinor)}`).join(",");
  return `ok;sub=${n(v.subtotalMinor)};disc=${n(v.discountMinor)};tax=${n(v.taxMinor)};total=${n(v.totalMinor)};lines=${lines}`;
}

const file = process.argv[2];
const text = file ? await Bun.file(file).text() : await Bun.stdin.text();
for (const raw of text.split("\n")) {
  const input = (raw.split(" => ")[0] ?? "").trim();
  if (input === "" || input.startsWith("#")) continue;
  console.log(`${input} => ${format(parse(input))}`);
}
