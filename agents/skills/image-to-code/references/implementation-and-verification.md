# Implementation and Verification

## Build Order

1. Establish page frame, type, palette, and spacing tokens.
2. Implement the first viewport and one representative section.
3. Verify the system before repeating it across the page.
4. Add distinct sections, responsive behavior, states, and motion.
5. Reuse project components where they can reach the required fidelity without distorting semantics.

## Comparison Loop

Render at the reference viewport and at mobile and small-laptop sizes. Compare:

- major geometry and section heights;
- headline wrapping and type hierarchy;
- whitespace and alignment;
- image crop and focal point;
- color, contrast, borders, and shadows;
- control size and state;
- overflow and responsive order.

Fix high-area and high-salience differences before small decoration. Re-render after each meaningful group of changes.

If a reference cannot determine behavior, choose the simplest accessible interaction consistent with the product and disclose the inference.
