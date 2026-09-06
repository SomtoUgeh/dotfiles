# Interface Design for Testability

Prefer a small interface that expresses the caller's task. Inject dependencies
at a real I/O boundary when that makes failure and timing controllable; pure
computation usually needs no adapter.

```typescript
type Order = { total: number };
type PaymentResult = { receiptId: string };
type PaymentGateway = {
  charge: (amount: number) => Promise<PaymentResult>;
};

export function processOrder(order: Order, gateway: PaymentGateway) {
  return gateway.charge(order.total);
}
```

These are application-owned example types, not a Stripe SDK API. Production
wiring adapts the selected provider's actual contract; tests supply a deliberate
boundary fake or use the provider's test environment.

Prefer returned values for pure calculations:

```typescript
export function calculateDiscount(total: number, rate: number): number {
  if (!Number.isFinite(total) || total < 0 || !Number.isFinite(rate) || rate < 0 || rate > 1) {
    throw new RangeError("Expected a nonnegative total and a rate between 0 and 1");
  }
  return total * rate;
}
```

This illustrates a pure numeric interface, not a monetary rounding policy.
Use the domain's money representation and rounding rules for actual pricing.
Side effects remain necessary at system boundaries; test their observable
results and failure behavior rather than banning them.
