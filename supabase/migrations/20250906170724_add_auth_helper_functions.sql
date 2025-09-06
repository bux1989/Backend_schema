--
-- Migration: Add Auth Helper Functions for Policies
-- This migration adds the missing auth schema helper functions that are referenced
-- by existing policies but were not defined in the previous schema migration.
--

--
-- Name: auth.get_user_role(); Type: FUNCTION; Schema: auth; Owner: -
--
CREATE OR REPLACE FUNCTION auth.get_user_role() RETURNS text
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
-- Name: auth.user_has_role(text); Type: FUNCTION; Schema: auth; Owner: -
--
CREATE OR REPLACE FUNCTION auth.user_has_role(required_role text) RETURNS boolean
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
-- Name: auth.get_profile_id(); Type: FUNCTION; Schema: auth; Owner: -
--
CREATE OR REPLACE FUNCTION auth.get_profile_id() RETURNS uuid
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
-- Name: auth.get_user_family_ids(); Type: FUNCTION; Schema: auth; Owner: -
--
CREATE OR REPLACE FUNCTION auth.get_user_family_ids() RETURNS uuid[]
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