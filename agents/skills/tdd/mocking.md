# When to Mock

Prefer real internal code. Use controlled doubles at boundaries where real I/O,
time, randomness, or failures would make a test unreliable or costly. A database
fixture or local service can prove behavior that a mock cannot, including
constraints, transactions, serialization, and query syntax.

A boundary can be owned by your team and still need a fake, such as another
service across the network. Ownership alone does not decide the testing method.
Do not add an abstraction solely to satisfy a blanket ban on internal mocks.

## Explicit application port

```typescript
type Order = { total: number; id: string };
type PaymentClient = {
  charge: (input: { amount: number; idempotencyKey: string }) => Promise<string>;
};

export function processPayment(order: Order, client: PaymentClient) {
  return client.charge({ amount: order.total, idempotencyKey: order.id });
}
```

`PaymentClient` is an application-owned example, not a real provider export.
Test both returned behavior and a relevant external effect such as preserving
the idempotency key across retries. Verify the real provider adapter separately.

## Choose the right HTTP test boundary

Operation-specific ports make domain tests readable. Mocking standard `fetch`
with an established request-interception tool is also valid when testing HTTP
paths, headers, serialization, cancellation, and error responses. Do not replace
every HTTP client with a custom SDK solely to make mocks look simpler.

Match the project's runner and mocking library. A passing fake proves only the
behavior it models; it does not prove that the real external contract matches.
