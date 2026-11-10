import type { Order, OrderId } from "../../contracts";

export interface OrderStore {
  get(id: OrderId): Order | undefined;
  put(order: Order): void;
  list(): readonly Order[];
}

export function createInMemoryOrderStore(seed: readonly Order[] = []): OrderStore {
  const byId = new Map<OrderId, Order>(seed.map((o) => [o.id, o]));
  return {
    get: (id) => byId.get(id),
    put: (order) => {
      byId.set(order.id, order);
    },
    list: () => [...byId.values()],
  };
}
