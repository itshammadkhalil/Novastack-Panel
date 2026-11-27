-- NovaStack Dashboard — Supabase schema (Phase 2, real backend)
-- Run this in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Auth: Supabase Auth (email + password). Founder = role 'founder', clients = role 'client'.
-- A client record is linked to its login by email (clients.email = auth user email).
-- No fake data is inserted here. The founder adds real clients from the dashboard.

-- 1) Profiles: one row per auth user, holds the role.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  role text not null default 'client' check (role in ('founder', 'client')),
  created_at timestamptz not null default now()
);

-- 2) Clients: the agency's clients, created by the founder.
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  company text,
  phone text,
  service text,
  status text not null default 'active' check (status in ('active', 'paused', 'completed')),
  created_at timestamptz not null default now()
);

-- 3) Projects: one project per client (a client can have more later).
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  title text not null,
  service text,
  status text not null default 'in_progress' check (status in ('in_progress', 'review', 'waiting_on_client', 'completed')),
  progress int not null default 0 check (progress >= 0 and progress <= 100),
  total_amount numeric not null default 0,
  currency text not null default 'PKR',
  start_date date,
  created_at timestamptz not null default now()
);

-- 4) Milestones: Design, Development, Review, Launch, etc.
create table if not exists public.milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'done')),
  sort_order int not null default 0,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- 5) Updates: founder posts, client reads in the feed.
create table if not exists public.updates (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  author_role text not null default 'founder' check (author_role in ('founder', 'client')),
  title text not null,
  body text,
  created_at timestamptz not null default now()
);

-- 6) Payments: amounts in PKR (or the project's currency).
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  amount numeric not null,
  method text,
  status text not null default 'paid' check (status in ('paid', 'pending')),
  paid_at timestamptz,
  note text,
  created_at timestamptz not null default now()
);

-- 7) Deliverables: links/files the founder shares with the client.
create table if not exists public.deliverables (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  kind text,
  url text,
  created_at timestamptz not null default now()
);

-- 8) Messages: client to founder (and founder replies) per project.
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  sender_role text not null check (sender_role in ('founder', 'client')),
  body text not null,
  created_at timestamptz not null default now()
);

-- 9) Row Level Security: founder sees everything, a client sees only
--    projects whose client email matches their login email.
alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.milestones enable row level security;
alter table public.updates enable row level security;
alter table public.payments enable row level security;
alter table public.deliverables enable row level security;
alter table public.messages enable row level security;

-- Helper: is the logged-in user the founder?
-- SECURITY DEFINER so it bypasses RLS when checking profiles (avoids recursion).
create or replace function public.is_founder()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'founder'
  );
$$;

-- Profiles: a user reads their own row; founder reads all and updates roles.
-- (No blanket "for all" policy: that would let any user set their own role to founder.)
create policy "read own profile" on public.profiles
  for select using (id = auth.uid() or public.is_founder());
create policy "founder update profiles" on public.profiles
  for update using (public.is_founder());

-- Clients: founder full access; a client reads only their own row (by email).
create policy "founder all clients" on public.clients
  for all using (public.is_founder());
create policy "client own row" on public.clients
  for select using (email = (auth.jwt() ->> 'email'));

-- Projects and everything under a project: founder full access;
-- a client reads only projects of their own client record.
create policy "founder all projects" on public.projects
  for all using (public.is_founder());
create policy "client own projects" on public.projects
  for select using (client_id in (
    select id from public.clients
    where email = (auth.jwt() ->> 'email')
  ));

-- Milestones / updates / payments / deliverables / messages follow the project.
create policy "founder all milestones" on public.milestones
  for all using (public.is_founder());
create policy "client own milestones" on public.milestones
  for select using (project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));

create policy "founder all updates" on public.updates
  for all using (public.is_founder());
create policy "client own updates" on public.updates
  for select using (project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));

create policy "founder all payments" on public.payments
  for all using (public.is_founder());
create policy "client own payments" on public.payments
  for select using (project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));

create policy "founder all deliverables" on public.deliverables
  for all using (public.is_founder());
create policy "client own deliverables" on public.deliverables
  for select using (project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));

create policy "founder all messages" on public.messages
  for all using (public.is_founder());
create policy "client own messages" on public.messages
  for select using (project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));
create policy "client send messages" on public.messages
  for insert with check (sender_role = 'client' and project_id in (
    select p.id from public.projects p
    join public.clients c on c.id = p.client_id
    where c.email = (auth.jwt() ->> 'email')
  ));

-- 10) Auto-create a profile row when a user signs up (default role: client).
--     After the founder signs up, set their profile role to 'founder' once:
--     update public.profiles set role = 'founder' where email = '<founder email>';
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name', 'client')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
