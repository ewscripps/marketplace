## Findings (L13: Type Design)

| ID | Sev | File:Line | What Is Wrong | Concrete Fix |
|----|-----|-----------|---------------|--------------|
| L13-001 | P2 | src/domain/order.ts:14 | `status: string` on `Order` lets any string compile, including values no code path ever assigns; the invariant "status is one of a fixed set" is enforced only by convention, not by the type system | Replace with a string-literal union (`"pending" \| "shipped" \| "cancelled"`) or an enum so an illegal state cannot be constructed |

## Noted / Not Actionable

| ID | File:Line | Rationale |
|----|-----------|-----------|
| L13-002 | src/domain/money.ts:5 | `Money` already pairs `amount` and `currency` in one type, so a bare-number arithmetic mistake that mixes currencies is a compile error rather than a runtime bug -- exactly the invariant-enforcement this lens looks for |
