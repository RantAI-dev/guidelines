# Pricing rules

All arithmetic is on integer minor units. "Round" means round half up.

1. Line subtotal = `qty × unitMinor`.
2. Line discount = round(line subtotal × `couponPct` / 100). The discount is taken on the line
   subtotal, never on the unit price.
3. Cart subtotal and cart discount are the sums over lines.
4. Tax = round((cart subtotal − cart discount) × `taxBps` / 10000).
5. Total = cart subtotal − cart discount + tax.

`couponPct` is 0–100 and defaults to 0. `taxBps` is 0–10000. A cart needs at least one line.
