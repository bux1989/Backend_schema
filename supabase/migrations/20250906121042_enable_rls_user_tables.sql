--
-- Migration: Enable Row Level Security for User Tables
-- 
-- This migration enables RLS on user_* tables that frequently experience
-- locking issues during CI/remote pushes. Split from main schema migration 
-- to reduce lock contention and add proper timeout protection.
--
-- Issue: https://github.com/bux1989/Backend_schema/issues/13
-- Context: ACCESS EXCLUSIVE locks on user tables hang during CI due to 
-- connection pooling and concurrent database activity
--

-- Set reasonable timeouts to prevent indefinite hangs (2 minute max per acceptance criteria)
SET statement_timeout = '2min';
SET lock_timeout = '2min';

-- Enable idle transaction timeout to prevent stuck transactions
SET idle_in_transaction_session_timeout = '2min';

-- Log what we're doing for debugging
DO $$
BEGIN
    RAISE NOTICE 'Starting user table RLS migration with 2-minute timeouts...';
    RAISE NOTICE 'Current time: %', now();
END;
$$;

-- Enable RLS on user tables (the tables mentioned in the issue)
-- These operations require ACCESS EXCLUSIVE locks but should complete quickly
-- if there are no long-running transactions blocking them

-- User groups table
ALTER TABLE public.user_groups ENABLE ROW LEVEL SECURITY;

-- User MFA preferences table  
ALTER TABLE public.user_mfa_preferences ENABLE ROW LEVEL SECURITY;

-- User profiles table
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- User roles table
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- User trusted devices table
ALTER TABLE public.user_trusted_devices ENABLE ROW LEVEL SECURITY;

-- Additional user-related tables that may also cause issues
ALTER TABLE public.user_codes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_group_members ENABLE ROW LEVEL SECURITY;

-- Log progress
DO $$
BEGIN
    RAISE NOTICE 'User table RLS migration completed successfully at %', now();
    RAISE NOTICE 'All user_* tables now have Row Level Security enabled.';
END;
$$;

-- Reset timeouts to default for subsequent operations
RESET statement_timeout;
RESET lock_timeout;
RESET idle_in_transaction_session_timeout;