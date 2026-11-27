-- NovaStack Dashboard — hardening migration (2026-11-27, part 2)
-- Run once in Supabase SQL Editor on the EXISTING project.
-- (Fresh installs get this from supabase/schema.sql already.)
-- SECURITY DEFINER functions must pin search_path so a malicious
-- search_path cannot redirect their names to attacker-owned tables.
-- is_founder() already sets search_path = public; this adds it to
-- handle_new_user(), the signup trigger that creates profile rows.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name', 'client')
  on conflict (id) do nothing;
  return new;
end;
$$;
