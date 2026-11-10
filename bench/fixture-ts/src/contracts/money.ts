import { z } from "zod";

// Amounts are integers in the currency's minor unit (USD cents, JPY yen, KWD fils).
export const CURRENCY_MINOR_UNITS = { USD: 2, JPY: 0, KWD: 3 } as const;

export const Currency = z.enum(["USD", "JPY", "KWD"]);
export type Currency = z.infer<typeof Currency>;

export const MinorAmount = z.number().int();
