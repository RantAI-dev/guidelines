import { z } from "zod";

export const OrderId = z
  .string()
  .regex(/^ord_[a-z0-9]{6,}$/)
  .brand<"OrderId">();
export type OrderId = z.infer<typeof OrderId>;

export const Sku = z
  .string()
  .regex(/^[A-Z0-9][A-Z0-9-]{1,31}$/)
  .brand<"Sku">();
export type Sku = z.infer<typeof Sku>;
