# NovaStack Panel

Client and founder dashboard for NovaStack, the digital agency. Clients sign in to follow their own project. The founder signs in to manage every client, project, milestone, update, payment, deliverable and message in one place.

Live agency site: https://www.novastackltd.com

## What it does

### Founder view

- See all clients and projects with live stats: total clients, active projects, projects waiting on client input, total project value
- Search clients by name, company or service, and filter by project status
- Add a client, which creates their first project and a standard milestone plan
- Edit project settings: title, status, progress and value
- Update milestones. Progress recalculates from milestones automatically
- Post updates the client sees in their feed
- Record payments, mark them paid or pending, and track paid versus remaining amounts
- Add or remove deliverables with working links
- Reply to client messages

### Client view

- See only their own project. Clients can never see another client's data
- Progress ring and overall progress percentage
- Milestones with Done, In Progress and Pending status
- Updates feed from the founder
- Payments with paid and remaining totals
- Deliverables with links
- A waiting-on-you card when the founder needs input
- A message box to write to the founder

When there is no data yet, every section shows an honest empty state. There is no demo or sample data in this app.

## Tech stack

- Static HTML, CSS and JavaScript. No build step and no framework
- Supabase Auth for email and password login
- Supabase Postgres for all data
- Supabase Row Level Security so a client only ever reads their own project
- Supabase JS client pinned to an exact version, with a restrictive Content Security Policy in the page

## Project structure

- `index.html` — the whole dashboard app
- `.htaccess` — security headers for Apache hosts such as Hostinger
- `supabase/schema.sql` — database tables, security policies and the signup trigger
- `supabase/tests-access-control.sql` — 42 regression checks for access control and constraints
- `supabase/migration-*.sql` — migrations applied after the initial schema, in date order
- `.gitignore` — blocks env files, keys and secrets from ever being committed
- `README.md` — this file

## Setup

### 1. Create a Supabase project

Create a free project at supabase.com. Note the Project URL and the publishable key from Settings, API Keys.

### 2. Run the schema

In the Supabase dashboard, open SQL Editor, create a new query, paste the contents of `supabase/schema.sql` and run it. This creates the tables `profiles`, `clients`, `projects`, `milestones`, `updates`, `payments`, `deliverables` and `messages`, enables Row Level Security on all of them, and adds a trigger that creates a profile row when a user signs up.

After the schema, run any migration files in `supabase/` in date order, then run `supabase/tests-access-control.sql`. The test run rolls itself back and should end with ALL ACCESS-CONTROL TESTS PASSED (42 tests).

### 3. Connect the app

Open `index.html` and set the Supabase Project URL and publishable key in the configuration at the top of the script. The file shipped in this repo is already configured for the NovaStack project.

### 4. Create the founder account

Open the dashboard, choose Create account, and sign up with the founder email. Then run this line in SQL Editor, replacing the email with the founder email:

```sql
update public.profiles set role = 'founder' where email = 'hammadkhalil.me@gmail.com';
```

Sign out and sign back in. The founder view unlocks.

### 5. Add the first client

In the founder view, use Add a client. Enter the client name, the email the client will sign in with, the project title, service and value. The client then creates their own account with that same email and sees only their project.

## Deployment

This is a static site, so it can be hosted anywhere that serves static files:

- Hostinger: create a subdomain such as `dashboard.novastackltd.com`, upload `index.html` as the subdomain root file, and open the subdomain
- Netlify, Vercel or Cloudflare Pages: deploy the repo or upload `index.html`
- Any static host: serve `index.html` over HTTPS

After deploying, set the Site URL in Supabase under Authentication, URL Configuration to the dashboard URL, so confirmation emails link back to the right place. Also add the dashboard URL to Redirect URLs, keep Confirm email ON and anonymous sign-ins OFF, and leave Auth rate limits at their defaults. On Hostinger, the `.htaccess` in this repo sets security headers (nosniff, frame deny, strict referrer policy). Verify them after deploy, for example with securityheaders.com.

## Security

- The publishable key in `index.html` is public by design. Supabase states that publishable keys can be safely shared publicly and used in a browser. It only allows what Row Level Security permits.
- Row Level Security is what protects the data. A client reads only the project whose client email matches their login email. The founder reads everything. Policies are deny-by-default on all 8 tables.
- Never commit a secret key or service role key to this repo. The secret key bypasses Row Level Security and must stay in Supabase only.
- Never commit a database password or any personal password.
- Client isolation is enforced in the database, not only in the interface.

### Audits

Three security audit rounds were run on this app in November 2026, and their fixes are in this repo:

1. **Access control.** RLS verified deny-by-default, clients isolated by login email, all writes founder-only except a client's own messages, and the signup trigger hardcodes role `client` so nobody can promote themselves. The frontend is fail-closed: no view renders before the server returns a confirmed profile, and sign-out wipes all local state. One real gap was found and fixed: `payments.amount` and `projects.total_amount` had no non-negative constraint. A founder-only **Access control tests** panel in the app runs 12 live probes against the real backend.
2. **XSS and hardening.** User content is rendered through escaping, never raw HTML. A restrictive Content Security Policy is set in the page. One real gap was found and fixed: the `handle_new_user()` function was missing a pinned `search_path`. All data access uses the parameterized Supabase query builder, so there is no string-built SQL.
3. **SSRF, dependencies and mass assignment.** Deliverable links pass a strict destination check that blocks cloud metadata endpoints, localhost and private IP ranges. The Supabase client library is pinned to an exact version. Create and update calls use explicit field allowlists, all form fields have length limits, and error messages shown to users are generic. No WebSockets, no file uploads, no OAuth providers and no AI integrations exist in this app, so there is nothing to audit there.

### Regression tests

- `supabase/tests-access-control.sql` runs 42 checks in one transaction that rolls back: anonymous denials, client A versus client B isolation, founder access, and boundary values (negative amounts rejected, zero allowed, progress above 100 rejected). Run it after any schema or migration change and expect all 42 to pass.
- The in-app **Access control tests** panel (founder only) runs 12 live probes after each deploy and should show 12 of 12 passed.

### Production checklist

- Serve over HTTPS with the Site URL and Redirect URLs set in Supabase Auth.
- Keep **Confirm email ON**, anonymous sign-ins OFF, and new signups ON.
- Enable secret scanning and push protection in GitHub under Settings, Code security, and turn on Dependabot alerts for the pinned Supabase client version.

## Local run

For a quick check, open `index.html` in a browser. For a closer match to production, serve the folder over HTTP, for example:

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000.

## Notes

- Each project has a currency, PKR or USDT, chosen by the founder. Amounts are recorded and shown in the project's currency. The founder sends any USDT wallet address to the client by message; no wallet address is stored in the dashboard.
- A client account is linked to its project by email. If a client signs up with a different email, they will see a "no project linked yet" screen until the founder adds a client record with that email.
- Email confirmation follows the Supabase Auth settings for the project.
