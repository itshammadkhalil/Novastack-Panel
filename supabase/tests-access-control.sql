-- NovaStack Dashboard — access-control regression tests
-- Run this whole file as ONE query in Supabase SQL Editor.
-- It simulates anonymous users, a client, and the founder by setting the
-- JWT claims Supabase Auth would normally provide, then asserts that
-- unauthorized requests are denied and authorized ones succeed.
-- Everything runs inside one transaction and is rolled back at the end,
-- so it never changes real data. A failed test raises an exception naming
-- how many tests failed; a clean run ends with
-- "ALL ACCESS-CONTROL TESTS PASSED".
-- Requires: at least one profile with role 'founder' (the founder account).
-- Run the migrations FIRST (migration-2026-11-27-amount-checks.sql and
-- migration-2026-11-27-function-search-path.sql): the negative-amount
-- boundary tests depend on those CHECK constraints, and the
-- function-hardening tests depend on the pinned search_path.
-- The client fixtures below are synthetic test rows, not real clients.

begin;

-- Results table (temporary; granted so the anon/authenticated roles can write it)
create temp table test_results (
  test text primary key,
  passed boolean not null,
  detail text
);
grant all on test_results to anon, authenticated;

-- Fixtures (created as postgres, which bypasses RLS; rolled back at the end)
insert into public.clients (id, name, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Client A', 'client-a-test@novastack.test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Test Client B', 'client-b-test@novastack.test');

insert into public.projects (id, client_id, title, total_amount) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Project A', 10000),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Test Project B', 20000);

insert into public.milestones (project_id, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Design', 'done'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Design', 'pending');

insert into public.updates (project_id, author_role, title, body) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'founder', 'Update A', 'Hello A'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'founder', 'Update B', 'Hello B');

insert into public.payments (project_id, amount, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 5000, 'paid'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 8000, 'pending');

insert into public.deliverables (project_id, title, url) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'File A', 'https://example.com/a'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'File B', 'https://example.com/b');

insert into public.messages (project_id, sender_role, body) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'founder', 'Hello A'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'founder', 'Hello B');

-- ============ 1) ANONYMOUS: no login, no access to anything ============
select set_config('request.jwt.claims', '{}', true);
set role anon;

do $$
declare t text; n int;
begin
  foreach t in array array['profiles','clients','projects','milestones','updates','payments','deliverables','messages'] loop
    begin
      execute format('select count(*) from public.%I', t) into n;
      if n = 0 then
        insert into test_results values ('anon cannot read ' || t, true, '0 rows');
      else
        insert into test_results values ('anon cannot read ' || t, false, n || ' rows visible');
      end if;
    exception when others then
      insert into test_results values ('anon cannot read ' || t, true, 'denied: ' || left(sqlerrm, 80));
    end;
  end loop;
end $$;

do $$
begin
  insert into public.clients (name, email) values ('Intruder', 'intruder@novastack.test');
  insert into test_results values ('anon cannot create a client', false, 'insert succeeded');
exception when others then
  insert into test_results values ('anon cannot create a client', true, 'denied: ' || left(sqlerrm, 80));
end $$;

do $$
begin
  insert into public.messages (project_id, sender_role, body)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'founder', 'spoofed hello');
  insert into test_results values ('anon cannot send a founder-spoofed message', false, 'insert succeeded');
exception when others then
  insert into test_results values ('anon cannot send a founder-spoofed message', true, 'denied: ' || left(sqlerrm, 80));
end $$;

do $$
declare changed int;
begin
  update public.profiles set role = 'founder' where email = 'client-a-test@novastack.test';
  get diagnostics changed = row_count;
  if changed = 0 then
    insert into test_results values ('anon cannot promote anyone to founder', true, '0 rows changed');
  else
    insert into test_results values ('anon cannot promote anyone to founder', false, changed || ' rows changed');
  end if;
exception when others then
  insert into test_results values ('anon cannot promote anyone to founder', true, 'denied: ' || left(sqlerrm, 80));
end $$;

reset role;

-- ============ 2) CLIENT A: sees only their own project ============
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","email":"client-a-test@novastack.test","role":"authenticated"}', true);
set role authenticated;

do $$
declare n int; changed int;
begin
  select count(*) into n from public.projects where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  insert into test_results values ('client can read own project', n = 1, n || ' rows');

  select count(*) into n from public.projects where id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client project', n = 0, n || ' rows');

  select count(*) into n from public.milestones where project_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  insert into test_results values ('client can read own milestones', n = 1, n || ' rows');
  select count(*) into n from public.milestones where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client milestones', n = 0, n || ' rows');

  select count(*) into n from public.payments where project_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  insert into test_results values ('client can read own payments', n = 1, n || ' rows');
  select count(*) into n from public.payments where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client payments', n = 0, n || ' rows');

  select count(*) into n from public.updates where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client updates', n = 0, n || ' rows');

  select count(*) into n from public.deliverables where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client deliverables', n = 0, n || ' rows');

  select count(*) into n from public.messages where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  insert into test_results values ('client cannot read another client messages', n = 0, n || ' rows');

  select count(*) into n from public.clients;
  insert into test_results values ('client sees only their own client row', n = 1, n || ' rows');

  select count(*) into n from public.profiles;
  insert into test_results values ('client cannot read other profiles', n = 0, n || ' rows');

  update public.milestones set status = 'pending' where project_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics changed = row_count;
  insert into test_results values ('client cannot change a milestone', changed = 0, changed || ' rows changed');

  update public.projects set progress = 100 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
  get diagnostics changed = row_count;
  insert into test_results values ('client cannot change project progress', changed = 0, changed || ' rows changed');

  begin
    insert into public.payments (project_id, amount, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 100, 'paid');
    insert into test_results values ('client cannot record a payment', false, 'insert succeeded');
  exception when others then
    insert into test_results values ('client cannot record a payment', true, 'denied: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.updates (project_id, author_role, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'founder', 'fake update');
    insert into test_results values ('client cannot post an update', false, 'insert succeeded');
  exception when others then
    insert into test_results values ('client cannot post an update', true, 'denied: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.messages (project_id, sender_role, body) values ('aaaaaaaa-0000-0000-0000-000000000001', 'client', 'test message from client A');
    insert into test_results values ('client can message on own project', true, 'insert succeeded');
  exception when others then
    insert into test_results values ('client can message on own project', false, 'denied: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.messages (project_id, sender_role, body) values ('bbbbbbbb-0000-0000-0000-000000000002', 'client', 'cross-account probe');
    insert into test_results values ('client cannot message another client project', false, 'insert succeeded');
  exception when others then
    insert into test_results values ('client cannot message another client project', true, 'denied: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.messages (project_id, sender_role, body) values ('aaaaaaaa-0000-0000-0000-000000000001', 'founder', 'spoofed founder message');
    insert into test_results values ('client cannot spoof founder in a message', false, 'insert succeeded');
  exception when others then
    insert into test_results values ('client cannot spoof founder in a message', true, 'denied: ' || left(sqlerrm, 80));
  end;

  update public.profiles set role = 'founder' where id = '22222222-2222-2222-2222-222222222222';
  get diagnostics changed = row_count;
  insert into test_results values ('client cannot promote self to founder', changed = 0, changed || ' rows changed');
end $$;

reset role;

-- ============ 3) FOUNDER: full access, and boundary checks ============
-- Fetch the real founder id first (runs as postgres), then test as them.
do $$
declare founder_id uuid; founder_email text;
begin
  select id, email into founder_id, founder_email
  from public.profiles where role = 'founder' order by created_at limit 1;
  if founder_id is null then
    raise exception 'no founder profile found — create the founder account and run the promotion SQL first';
  end if;
  perform set_config('request.jwt.claims',
    json_build_object('sub', founder_id, 'email', founder_email, 'role', 'authenticated')::text, true);
  insert into test_results values ('founder profile exists for test', true, founder_email);
end $$;

set role authenticated;

do $$
declare n int; changed int;
begin
  select count(*) into n from public.clients;
  insert into test_results values ('founder can read all clients', n >= 2, n || ' rows');

  select count(*) into n from public.projects;
  insert into test_results values ('founder can read all projects', n >= 2, n || ' rows');

  update public.milestones set status = 'in_progress' where project_id = 'bbbbbbbb-0000-0000-0000-000000000002';
  get diagnostics changed = row_count;
  insert into test_results values ('founder can update a milestone', changed = 1, changed || ' rows changed');

  begin
    insert into public.payments (project_id, amount, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 2500, 'paid');
    insert into test_results values ('founder can record a payment', true, 'insert succeeded');
  exception when others then
    insert into test_results values ('founder can record a payment', false, 'denied: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.payments (project_id, amount, status) values ('aaaaaaaa-0000-0000-0000-000000000001', -100, 'paid');
    insert into test_results values ('negative payment amount is rejected', false, 'insert succeeded');
  exception when others then
    insert into test_results values ('negative payment amount is rejected', true, 'rejected: ' || left(sqlerrm, 80));
  end;

  begin
    insert into public.payments (project_id, amount, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 0, 'pending');
    insert into test_results values ('zero payment amount is allowed', true, 'insert succeeded');
  exception when others then
    insert into test_results values ('zero payment amount is allowed', false, 'rejected: ' || left(sqlerrm, 80));
  end;

  begin
    update public.projects set progress = 101 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
    insert into test_results values ('progress above 100 is rejected', false, 'update succeeded');
  exception when others then
    insert into test_results values ('progress above 100 is rejected', true, 'rejected: ' || left(sqlerrm, 80));
  end;

  begin
    update public.projects set progress = 100 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
    insert into test_results values ('progress 100 is allowed', true, 'update succeeded');
  exception when others then
    insert into test_results values ('progress 100 is allowed', false, 'rejected: ' || left(sqlerrm, 80));
  end;

  begin
    update public.projects set total_amount = -5 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
    insert into test_results values ('negative project total is rejected', false, 'update succeeded');
  exception when others then
    insert into test_results values ('negative project total is rejected', true, 'rejected: ' || left(sqlerrm, 80));
  end;
end $$;

reset role;

-- ============ 4) FUNCTION HARDENING: SECURITY DEFINER functions pin search_path ============
do $$
declare cfg text[];
begin
  select proconfig into cfg from pg_proc
  where proname = 'handle_new_user' and pronamespace = 'public'::regnamespace;
  insert into test_results values ('handle_new_user pins search_path',
    cfg is not null and 'search_path=public' = any(cfg),
    'proconfig=' || coalesce(array_to_string(cfg, ','), 'null'));
  select proconfig into cfg from pg_proc
  where proname = 'is_founder' and pronamespace = 'public'::regnamespace;
  insert into test_results values ('is_founder pins search_path',
    cfg is not null and 'search_path=public' = any(cfg),
    'proconfig=' || coalesce(array_to_string(cfg, ','), 'null'));
end $$;

-- ============ Summary ============
select * from test_results order by test;

do $$
declare fails int; total int;
begin
  select count(*) into total from test_results;
  select count(*) into fails from test_results where not passed;
  if fails > 0 then
    raise exception '% of % access-control tests FAILED', fails, total;
  else
    raise notice 'ALL ACCESS-CONTROL TESTS PASSED (% tests)', total;
  end if;
end $$;

rollback;
