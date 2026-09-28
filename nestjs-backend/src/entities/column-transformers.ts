import { ValueTransformer } from 'typeorm';

/**
 * MySQL liefert DECIMAL als String und TINYINT als 0/1 — die Entities sind
 * aber mit number bzw. boolean typisiert. Ohne Transformer stimmt der Typ nur
 * auf dem Papier, und `springLoad - 1` ergäbe "3.00" - 1 = NaN-Überraschungen.
 */
export const decimalToNumber: ValueTransformer = {
  to: (value: number | null | undefined) => value ?? null,
  from: (value: string | number | null) => (value == null ? null : Number(value)),
};

export const tinyintToBoolean: ValueTransformer = {
  to: (value: boolean | null | undefined) => (value == null ? null : value ? 1 : 0),
  from: (value: number | boolean | null) => (value == null ? null : !!Number(value)),
};
