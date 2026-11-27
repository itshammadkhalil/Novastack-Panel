-- NovaStack Dashboard — hardening migration (2026-11-27)
-- Run once in Supabase SQL Editor on the EXISTING project.
-- (Fresh installs get these constraints from supabase/schema.sql already.)
-- Adds non-negative amount checks so a payment or project total can never
-- go below zero, even from a founder write or a future integration.
-- Re-runnable: each block skips itself if the constraint already exists.

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'projects_total_amount_nonnegative'
  ) then
    alter table public.projects
      add constraint projects_total_amount_nonnegative check (total_amount >= 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_amount_nonnegative'
  ) then
    alter table public.payments
      add constraint payments_amount_nonnegative check (amount >= 0);
  end if;
end $$;
