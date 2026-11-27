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

## Project structure

- `index.html` — the whole dashboard app
- `supabase/schema.sql` — database tables, security policies and the signup trigger
- `README.md` — this file

## Setup

### 1. Create a Supabase project

Create a free project at supabase.com. Note the Project URL and the publishable key from Settings, API Keys.

### 2. Run the schema

In the Supabase dashboard, open SQL Editor, create a new query, paste the contents of `supabase/schema.sql` and run it. This creates the tables `profiles`, `clients`, `projects`, `milestones`, `updates`, `payments`, `deliverables` and `messages`, enables Row Level Security on all of them, and adds a trigger that creates a profile row when a user signs up.

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

After deploying, set the Site URL in Supabase under Authentication, URL Configuration to the dashboard URL, so confirmation emails link back to the right place.

## Security

- The publishable key in `index.html` is public by design. Supabase states that publishable keys can be safely shared publicly and used in a browser. It only allows what Row Level Security permits.
- Row Level Security is what protects the data. A client reads only the project whose client email matches their login email. The founder reads everything.
- Never commit a secret key or service role key to this repo. The secret key bypasses Row Level Security and must stay in Supabase only.
- Never commit a database password or any personal password.
- Client isolation is enforced in the database, not only in the interface.

## Local run

For a quick check, open `index.html` in a browser. For a closer match to production, serve the folder over HTTP, for example:

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000.

## Notes

- All amounts are stored in PKR unless a project says otherwise.
- A client account is linked to its project by email. If a client signs up with a different email, they will see a "no project linked yet" screen until the founder adds a client record with that email.
- Email confirmation follows the Supabase Auth settings for the project.
