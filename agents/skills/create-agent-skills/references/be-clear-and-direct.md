# Clear Instructions

State what the agent should produce, which inputs it should use, and how correctness is checked. Include audience or purpose only where it changes the result.

## Example

Instead of “clean the data,” specify: “Parse the supplied CSV, retain rows with a customer ID and valid date, normalize dates to ISO format, and return a JSON array. Report rejected row counts and reasons. Preserve the source file.” Define how duplicates and empty input are handled.

Use numbered steps when order matters. Use conditional rules when behavior depends on context. Distinguish “must,” “may,” and “if”; do not replace every discretionary choice with “always.”

## Output contracts

Show a small example when exact formatting matters. Use schema validation for machine-consumed output. A report template may define sections without forcing a quota of findings. Missing data stays missing or explicitly hypothetical.

## Completion and error cases

Define success through observable outputs and checks. Document invalid input, no results, incomplete reads, and failed writes. A permission error cannot silently become an empty successful result. Preserve recoverable originals until replacement output validates.

Test the instructions with a fresh reader or available agent that has only the declared inputs. Confusion, skipped references, and incorrect assumptions are evidence for a focused revision.
