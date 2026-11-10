# Plan T3 — cancel an order

## Goal

Support staff can cancel an order that has not left the warehouse.

## Decisions already made

- New file `src/features/orders/cancel-order.ts`, exported from the slice's `index.ts`:
  `cancelOrder(rawId: string, deps: { readonly store: OrderStore }): Result<Order, CancelOrderError>`
  and the `CancelOrderError` type.

## Behaviour

1. `rawId` is parsed with `OrderId`. Failure → `err({ type: "InvalidOrderId", value: rawId })`.
2. Not in the store → `err({ type: "OrderNotFound", id })`.
3. Status `pending` or `paid` → the order is saved with status `cancelled`, and returned.
4. Status `cancelled` already → returned unchanged. Cancelling twice is not an error.
5. Status `shipped` → `err({ type: "AlreadyShipped", id })`.

## Acceptance

The product owner has already added the contract tests in `tests/contract/orders.contract.test.ts`.
`bun run check` must pass.

## Out of scope

Refunds, notifications, any other slice.
