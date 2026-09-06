---
title: PostgreSQL Schema Design
description: Schema design guide
tags: postgres, schema, primary-keys, data-types, foreign-keys, naming
---

# Schema Design

## Primary Keys

Prefer `BIGINT GENERATED ALWAYS AS IDENTITY`. Avoid random UUIDs (UUIDv4) as primary keys; use time-ordered UUIDs when appropriate. Built-in `uuidv7()` requires PostgreSQL 18+; earlier versions need application generation or an approved extension.

```sql
CREATE TABLE user_account (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email TEXT NOT NULL UNIQUE
);
```

Random UUID PKs (v4) can cause index fragmentation; UUIDs are also larger (16 vs 8 bytes for BIGINT) and can slow joins.

## Data Types

| Use | Avoid |
| --- | --- |
| `TEXT`, `VARCHAR` | Extension-specific types |
| `JSONB` | Custom ENUMs (use CHECK instead) |
| `TIMESTAMPTZ` | `TIMESTAMP` without time zone |
| `BIGINT`, `INTEGER` | Platform-specific types |

Prefer CHECK constraints over ENUM types — they're easier to modify:

```sql
CREATE TABLE purchase_order (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  status TEXT NOT NULL CHECK (status IN ('pending', 'shipped', 'delivered'))
);
```

## Foreign Keys

- Evaluate FK indexes for joins and parent updates/deletes (PostgreSQL does not auto-create referencing indexes)
- Avoid circular FK dependencies
- Choose delete behavior from the domain: retain NO ACTION/RESTRICT when dependents should block deletion; CASCADE deletes dependents and SET NULL requires nullable columns.

```sql
CREATE TABLE purchase_order (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customer(id) ON DELETE CASCADE
);
CREATE INDEX order_customer_id_idx ON purchase_order (customer_id);
```

## Naming Conventions

- Tables: singular snake_case (`user_account`, `order_item`)
- Columns: singular snake_case (`created_at`, `user_id`)
- Indexes: `{table}_{column}_idx`
- Constraints: `{table}_{column}_{type}` (e.g., `order_status_check`)

## General Guidelines

- Add `NOT NULL` to as many columns as possible
- Add `created_at TIMESTAMPTZ DEFAULT NOW()` to all tables
- Use `BIGINT` for all IDs and foreign keys, even on small tables
- Keep tables normalized; denormalize only for proven hot read paths
