-- Reads the user's school_id from the JWT claims set by Supabase Auth.
-- Adjust the 'school_id' key below if your JWT claim uses a different name.
create or replace function auth.get_user_school_id()
returns uuid
language sql
stable
as $$
  select nullif(
           (current_setting('request.jwt.claims', true)::jsonb ->> 'school_id'),
           ''
         )::uuid
$$;

grant execute on function auth.get_user_school_id() to anon, authenticated, service_role;