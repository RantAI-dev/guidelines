# Plan T1 — invoice CSV export

## Goal

Finance selects orders in the console and downloads one CSV. Build the slice that produces the CSV text.

## Decisions already made

- New slice `src/features/invoice-export/`. Its `index.ts` exports
  `exportInvoicesCsv(orderIds: readonly string[], deps: { readonly store: OrderStore }): Result<string, ExportError>`
  and the `ExportError` type.
- It reads orders through `OrderStore` from the orders slice. It never writes to the store.

## Behaviour

Input handling, in this order:

1. Empty `orderIds` → `err({ type: "EmptySelection" })`.
2. Every id is parsed with `OrderId`. The first id (in input order) that fails →
   `err({ type: "InvalidOrderId", value })`. This check covers the whole list before any lookup.
3. Duplicate ids are dropped; the first occurrence counts.
4. The first id (in input order) that is not in the store → `err({ type: "OrderNotFound", id })`.
5. Orders with status `cancelled` are left out. If none remain → `err({ type: "NothingToExport" })`.
6. If the remaining orders use more than one currency →
   `err({ type: "MixedCurrencies", currencies })`, currencies sorted A–Z without repeats.

Output:

- Header row: `order_id,created_at,customer,sku,description,qty,unit_price,line_total`
- One row per order line. Orders are sorted by `createdAt` ascending, ties by `id` ascending.
  Lines keep their order inside an order. `created_at` is the stored string, unchanged.
- `line_total` = `qty × unitMinor`.
- Last row: `TOTAL,,,,,<sum of qty>,,<sum of line_total>`.
- Money columns (`unit_price`, `line_total`) are decimals in the currency's minor units from
  `CURRENCY_MINOR_UNITS`, with no thousands separator: USD `123456` → `1234.56`, USD `-5` → `-0.05`,
  JPY `500` → `500`, KWD `1500` → `1.500`.
- CSV follows RFC 4180: every row ends with CRLF, the last row too. A field that contains a comma,
  a double quote, CR or LF is wrapped in double quotes, and a quote inside it is doubled.
- Spreadsheet-formula guard: in the text columns `customer`, `sku` and `description`, a value that
  starts with `=`, `+`, `-` or `@` gets a leading `'`. The guard is applied before quoting. Number
  columns are never guarded.

## Out of scope

HTTP routes, file download, pagination, any change outside the new slice.
