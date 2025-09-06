--
-- Migration: Add Auth Helper Functions for Policies (EARLY)
-- This migration adds helper functions in the public schema that are referenced
-- by the main schema migration. Must run BEFORE 20250906121041_schema_app_only.sql
--
-- Note: Functions are created in public schema because Supabase restricts
-- user DDL operations in the auth schema.
--

-- Drop any existing auth schema functions that might have been created previously
DROP FUNCTION IF EXISTS auth.get_user_role() CASCADE;
DROP FUNCTION IF EXISTS auth.user_has_role(text) CASCADE;
DROP FUNCTION IF EXISTS auth.get_profile_id() CASCADE;
DROP FUNCTION IF EXISTS auth.get_user_family_ids() CASCADE;

--
-- Name: public.get_user_role(); Type: FUNCTION; Schema: public; Owner: -
--
CREATE OR REPLACE FUNCTION public.get_user_role() RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path = public, auth
    AS $$
DECLARE
    v_profile_id uuid;
    v_role_name text;
BEGIN
    -- Extract profile_id from auth metadata
    SELECT (auth.jwt() -> 'user_metadata' ->> 'profile_id')::uuid 
    INTO v_profile_id;
    
    -- If no profile_id in metadata, return null
    IF v_profile_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Look up role name using the profile_id
    SELECT r.name 
    INTO v_role_name
    FROM public.user_profiles up
    JOIN public.roles r ON up.role_id = r.id
    WHERE up.id = v_profile_id;
    
    RETURN v_role_name;
END;
$$;

--
-- Name: public.user_has_role(text); Type: FUNCTION; Schema: public; Owner: -
--
CREATE OR REPLACE FUNCTION public.user_has_role(required_role text) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path = public, auth
    AS $$
DECLARE
    v_profile_id uuid;
    v_has_role boolean;
BEGIN
    -- Extract profile_id from auth metadata
    SELECT (auth.jwt() -> 'user_metadata' ->> 'profile_id')::uuid 
    INTO v_profile_id;
    
    -- If no profile_id in metadata, return false
    IF v_profile_id IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check if user has the required role
    SELECT EXISTS(
        SELECT 1 
        FROM public.user_profiles up
        JOIN public.roles r ON up.role_id = r.id
        WHERE up.id = v_profile_id 
        AND r.name = required_role
    ) INTO v_has_role;
    
    -- Also check user_roles table for additional roles
    IF NOT v_has_role THEN
        SELECT EXISTS(
            SELECT 1 
            FROM public.user_roles ur
            JOIN public.roles r ON ur.role_id = r.id
            WHERE ur.user_profile_id = v_profile_id 
            AND r.name = required_role
        ) INTO v_has_role;
    END IF;
    
    RETURN v_has_role;
END;
$$;

--
-- Name: public.get_profile_id(); Type: FUNCTION; Schema: public; Owner: -
--
CREATE OR REPLACE FUNCTION public.get_profile_id() RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path = public, auth
    AS $$
DECLARE
    v_profile_id uuid;
BEGIN
    -- Extract profile_id from auth metadata
    SELECT (auth.jwt() -> 'user_metadata' ->> 'profile_id')::uuid 
    INTO v_profile_id;
    
    RETURN v_profile_id;
END;
$$;

--
-- Name: public.get_user_family_ids(); Type: FUNCTION; Schema: public; Owner: -
--
CREATE OR REPLACE FUNCTION public.get_user_family_ids() RETURNS uuid[]
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path = public, auth
    AS $$
DECLARE
    v_profile_id uuid;
    v_family_ids uuid[];
BEGIN
    -- Extract profile_id from auth metadata
    SELECT (auth.jwt() -> 'user_metadata' ->> 'profile_id')::uuid 
    INTO v_profile_id;
    
    -- If no profile_id in metadata, return empty array
    IF v_profile_id IS NULL THEN
        RETURN ARRAY[]::uuid[];
    END IF;
    
    -- Get all family IDs for this user (could be student or family member)
    SELECT ARRAY_AGG(DISTINCT fm.family_id)
    INTO v_family_ids
    FROM public.family_members fm
    WHERE fm.profile_id = v_profile_id
    AND fm.removed_at IS NULL;
    
    RETURN COALESCE(v_family_ids, ARRAY[]::uuid[]);
END;
$$;

--
-- Grant EXECUTE permissions to authenticated and anonymous users
-- These functions are called within RLS policies, so they need to be executable
-- by the roles that trigger policy evaluation
--
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.user_has_role(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_profile_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_family_ids() TO authenticated, anon;