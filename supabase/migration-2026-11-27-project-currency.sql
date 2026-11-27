-- NovaStack Dashboard — migration 2026-11-27: project currency PKR or USDT
-- Run this in Supabase SQL Editor: New query -> paste -> Run.
-- Restricts projects.currency to 'PKR' or 'USDT'. Existing projects keep
-- their currency (the default is 'PKR'), so this changes nothing stored.
-- Safe to run twice: the constraint is only added when it does not exist yet.

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'projects_currency_check'
  ) then
    alter table public.projects
      add constraint projects_currency_check check (currency in ('PKR', 'USDT'));
  end if;
end $$;
