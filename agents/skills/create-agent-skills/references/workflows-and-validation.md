# Workflows and Validation

## Ordered work

For a fragile operation, define prerequisites, inputs, transformations, validation, writes, and verification in that order. A checklist can track these steps without requiring a new file for every task.

For bulk writes, a structured plan can make the proposed changes reviewable. Validate scope and identifiers before execution, preserve originals until outputs pass, and reconcile partial outcomes before retries.

## Validation contract

A validator reports exactly what it checked. Errors identify the field/path, expected condition, and observed failure without leaking sensitive values. Warnings, skipped checks, and incomplete reads are separate from passes. Do not claim that XML or YAML parsing proves application behavior.

## Recovery

- Invalid input: report the error or correct it from authoritative task context.
- Network failure: use bounded retries only where the operation is safe to retry.
- Ambiguous write outcome: inspect actual state before repeating a write.
- Save failure: preserve the previous valid result and remove partial temporary output where possible.
- Cleanup failure: report the remaining resource and recovery step; do not return overall success.

Change approach after repeated identical failures. Ask for missing input only when independent work is exhausted and the answer is required.

## Completion

Verify the final artifact or application behavior, not just intermediate checks. Re-run affected tests after repairs. Record any unsupported runtime or live integration separately. Use [iteration-and-testing.md](iteration-and-testing.md) for coverage reporting.
