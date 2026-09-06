# Using Templates

Use templates for repeated output structures: plans, specifications, configurations, and scaffolds. Keep variable content clearly marked with `{{PLACEHOLDER}}` or `[PLACEHOLDER]`.

A workflow should say when to read the template, which evidence supplies each field, and how to validate the result. Infer supplied preferences; do not turn a template into a mandatory questionnaire.

Use Markdown headings for document templates. Quote placeholder values in YAML so the scaffold parses as strings. If a Markdown example contains code fences, make its outer fence longer than the inner fences.

Populate only supported facts. Leave unresolved required fields explicitly identified rather than inventing measurements, dates, sources, or approvals. Remove unused example resources and placeholders before delivering a finished skill.

Test at least one populated output and one case with missing required input. Parse machine-consumed formats with the real parser. Review rendered documents when presentation matters.
