-- Validation: Check that auth helper functions exist and are callable
-- This migration validates that the helper functions were created successfully
-- and can be executed by the authenticated and anon roles

-- Test that the helper functions exist and return expected types
DO $$
DECLARE
    v_role_result text;
    v_has_role_result boolean;  
    v_profile_result uuid;
    v_family_ids_result uuid[];
BEGIN
    -- Note: These will return NULL/false/empty for CI context, which is expected

    SELECT public.get_user_role() INTO v_role_result;
    RAISE NOTICE 'get_user_role() test: OK (returned: %)', COALESCE(v_role_result, 'NULL');

    SELECT public.user_has_role('Admin') INTO v_has_role_result;
    RAISE NOTICE 'user_has_role() test: OK (returned: %)', v_has_role_result;

    SELECT public.get_profile_id() INTO v_profile_result;  
    RAISE NOTICE 'get_profile_id() test: OK (returned: %)', COALESCE(v_profile_result::text, 'NULL');

    SELECT public.get_user_family_ids() INTO v_family_ids_result;
    RAISE NOTICE 'get_user_family_ids() test: OK (returned array length: %)', COALESCE(array_length(v_family_ids_result, 1), 0);

    RAISE NOTICE 'All helper function validation tests passed successfully!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Helper function validation failed: %', SQLERRM;
END;
$$;

-- Verify that the functions have proper permissions granted
-- Check that authenticated role can execute these functions
DO $$
BEGIN
    IF NOT has_function_privilege('authenticated', 'public.get_user_role()', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated role does not have EXECUTE permission on public.get_user_role()';
    END IF;

    IF NOT has_function_privilege('authenticated', 'public.user_has_role(text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated role does not have EXECUTE permission on public.user_has_role(text)';
    END IF;

    IF NOT has_function_privilege('authenticated', 'public.get_profile_id()', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated role does not have EXECUTE permission on public.get_profile_id()';
    END IF;

    IF NOT has_function_privilege('authenticated', 'public.get_user_family_ids()', 'EXECUTE') THEN
        RAISE EXCEPTION 'authenticated role does not have EXECUTE permission on public.get_user_family_ids()';
    END IF;

    RAISE NOTICE 'All permission checks passed - authenticated role has EXECUTE privileges on all helper functions';
END;
$$;

-- Optional: write a timestamped schema comment without using expression in COMMENT
DO $$
BEGIN
  EXECUTE format(
    'COMMENT ON SCHEMA public IS %L',
    'Auth helper function validation completed successfully at ' || now()::text
  );
END;
$$;
