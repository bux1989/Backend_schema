# Safe Migration Patterns for Supabase

This document outlines safe migration patterns to prevent deadlocks and hangs during CI/remote pushes, particularly when using Supabase's connection pooler.

## Problem Background

During CI runs and remote pushes, migrations can hang indefinitely when:
- Using ALTER TABLE operations that require ACCESS EXCLUSIVE locks
- Connection pooler (port 6543) is used instead of direct DB connection (port 5432)
- Active connections or long-running transactions block the lock acquisition
- No timeouts are set, allowing indefinite waiting

**Issue Reference**: [#13 - Migration locks: ALTER TABLE on user_* tables hangs during CI/remote push](https://github.com/bux1989/Backend_schema/issues/13)

## Safe Migration Patterns

### 1. Always Set Reasonable Timeouts

❌ **Don't do this:**
```sql
SET statement_timeout = 0;
SET lock_timeout = 0;
```

✅ **Do this instead:**
```sql
-- Set reasonable timeouts to prevent indefinite hangs
SET statement_timeout = '10min';  -- For large migrations
SET lock_timeout = '2min';        -- For lock acquisition
SET idle_in_transaction_session_timeout = '2min';
```

### 2. Split Blocking Operations into Separate Migrations

❌ **Don't do this:**
```sql
-- One large migration with many ALTER TABLE operations
ALTER TABLE table1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE table2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE table3 ADD CONSTRAINT ...;
-- ... many more operations
```

✅ **Do this instead:**
```sql
-- Migration 1: Create tables and functions
-- Migration 2: Enable RLS on critical tables (with short timeout)
-- Migration 3: Add constraints (with proper timeout)
```

### 3. Use Concurrent Operations When Possible

❌ **Don't do this via pooler:**
```sql
CREATE INDEX CONCURRENTLY idx_name ON table_name (column);  -- Fails on pooler
```

✅ **Do this instead:**
```sql
-- For migrations that must run on direct connection (5432)
-- Add comment explaining the requirement:
-- NOTE: This migration requires direct database connection (port 5432)
-- Connection pooler (port 6543) does not support CONCURRENTLY operations
CREATE INDEX CONCURRENTLY idx_name ON table_name (column);
```

### 4. Add Progress Logging for Long Operations

✅ **Good practice:**
```sql
DO $$
BEGIN
    RAISE NOTICE 'Starting migration at %', now();
END;
$$;

ALTER TABLE large_table ENABLE ROW LEVEL SECURITY;
RAISE NOTICE 'Enabled RLS on large_table at %', now();

-- More operations...

DO $$
BEGIN
    RAISE NOTICE 'Migration completed at %', now();
END;
$$;
```

### 5. Document Lock Requirements

✅ **Add migration headers:**
```sql
--
-- Migration: Enable Row Level Security for User Tables
-- 
-- Lock Requirements: ACCESS EXCLUSIVE on user_* tables
-- Expected Duration: < 30 seconds in normal conditions
-- CI Compatibility: Yes (with 2-minute timeout)
-- Pooler Compatibility: Yes
--
-- Issue: https://github.com/bux1989/Backend_schema/issues/13
--
```

## Migration Checklist

Before creating migrations that modify table structure:

- [ ] Set appropriate timeouts (`statement_timeout`, `lock_timeout`)
- [ ] Split large migrations into focused, smaller migrations
- [ ] Add progress logging for operations that might take time
- [ ] Document expected lock requirements and duration
- [ ] Test migration on a copy of production data if possible
- [ ] Consider if operation needs direct DB connection vs. pooler

## Example: Safe RLS Migration

See `20250906121042_enable_rls_user_tables.sql` for a complete example of:
- Proper timeout settings
- Progress logging
- Focused scope (only user_* tables)
- Clear documentation of purpose and context

## When Migrations Hang

If a migration hangs during CI:

1. **Check for blocking transactions**: Look for long-running queries in the database
2. **Verify timeout settings**: Ensure reasonable timeouts are set
3. **Consider splitting**: Break large migrations into smaller, focused ones
4. **Use direct connection**: Some operations may need port 5432 instead of 6543
5. **Add logging**: Include progress notifications to track where hangs occur

## Connection Types

- **Pooler (6543)**: Good for application connections, limited for some DDL operations
- **Direct DB (5432)**: Required for operations like `CREATE INDEX CONCURRENTLY`
- **CI/Migration Context**: Usually uses pooler, may have different connection behavior than local dev

---

**Last Updated**: Based on resolution of issue #13
**Related Issues**: [Migration locks: ALTER TABLE hangs during CI](https://github.com/bux1989/Backend_schema/issues/13)