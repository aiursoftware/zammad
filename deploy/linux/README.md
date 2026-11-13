# WCL Zammad on a Linux server

Zammad with the WCL changes on its own Linux server, with HTTPS. Employees sign in with their
**Microsoft 365** account and create tickets in Zammad directly. (The HR app integration is built
in and switched off until the HR app is connected — see the end.)

```text
Employees & agents ──HTTPS──►  support.worldcraftlogistics.net  (this server)
  (Microsoft 365 sign-in)        Caddy :443 → Zammad (nginx, rails, websocket, scheduler)
                                 PostgreSQL · Redis · Memcached · Elasticsearch
```

## Server

- Ubuntu 24.04 LTS (or Debian 12), **4 CPU, 8 GB RAM, 60 GB disk** (Elasticsearch and the image
  build are the hungry parts).
- Docker Engine with the compose plugin: <https://docs.docker.com/engine/install/ubuntu/>
- Elasticsearch needs this once on the host:

  ```bash
  echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf && sudo sysctl --system
  ```

- DNS: an **A record** for `support.worldcraftlogistics.net` → the server's public IP.
- Firewall: open **80** and **443** (80 is needed for the certificate). Nothing else.

## 1. Install

```bash
git clone https://github.com/aiursoftware/zammad.git && cd zammad   # the WCL fork, changes committed
cd deploy/linux
cp .env.example .env && nano .env      # ZAMMAD_FQDN, POSTGRES_PASSWORD
./build.sh                              # builds the image from this checkout (~15–25 min)
docker compose up -d
docker compose logs -f zammad-init      # first run ~5 min; done when it exits
```

Open `https://support.worldcraftlogistics.net` and run Zammad's setup wizard (your admin account,
organization name, **email channel** — needed for notifications and admin password login).

## 2. Groups and agents

- **Groups** (Admin → Groups → New): one per team. Tick **Customers can create tickets here** for
  the ones employees may pick (HR, IT, Payroll, …); leave it off for teams tickets are only handed
  to (Dev, Network). Every agent gets access to a new group automatically.
- **Agents** (Admin → Users → New, role _Agent_).
- **Departments** (Admin → Objects → User → Department): add your department names; employees'
  department is picked from this list. (Once the HR app is connected, it keeps this list for you.)

## 3. Microsoft 365 sign-in for employees

In the Azure portal (<https://portal.azure.com>), as someone who administers your Microsoft 365:

1. **Microsoft Entra ID → App registrations → New registration**
   - Name: `WCL Support (Zammad)`
   - Supported account types: **Accounts in this organizational directory only (single tenant)**
     — only your company's accounts can sign in.
   - Redirect URI: **Web** → `https://support.worldcraftlogistics.net/auth/microsoft_office365/callback`
2. On the app's **Overview**, copy the **Application (client) ID** and **Directory (tenant) ID**.
3. **Certificates & secrets → New client secret** (24 months), copy its **Value** now (shown
   once). Put a reminder in the calendar to renew it before it expires.
4. **API permissions**: Microsoft Graph, delegated **User.Read**, **openid**, **email**,
   **profile** → **Grant admin consent**.

In Zammad, **Admin → Settings → Security → Third-party Applications → Authentication via
Microsoft**: switch on, paste App ID, App Secret and App Tenant ID, save.

Test it in a private browser window: **Sign in with Microsoft** → the employee lands in Zammad as a
customer and can create tickets (group, priority, text, attachments).

Then, in **Admin → Settings → Security → Base**:

- **New User Accounts / Register as a new customer**: off (accounts come from Microsoft).
- **Show password login**: off, so the login page shows only the Microsoft button. Admins can still
  sign in with a password through _"Request the password login here"_ (a link by email — check the
  email channel works first).

## 4. Check

Takes a minute and leaves nothing behind:

```bash
docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb
```

Everything WCL needs in Zammad's data (Rejected state, Urgent priority that employees can pick,
Owners field, department dropdown, attachment settings, 30-day sessions, …) is created on the first
start. To re-apply it: `docker compose exec zammad-railsserver bundle exec rails zammad:wcl:setup`.

## Updates

```bash
cd zammad && git pull
cd deploy/linux && ./build.sh && docker compose up -d   # zammad-init runs the migrations
docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb
```

## Backups

`zammad-backup` writes a database + files backup to `./backup` every night at 03:00 and keeps 14
days. Copy that folder off the server (e.g. rsync/rclone to another machine or cloud storage).
Restore: <https://docs.zammad.org/en/latest/appendix/backup-and-restore/index.html>

## Troubleshooting

- `docker compose ps` — every service should be `running` (zammad-init `exited (0)`).
- `docker compose logs caddy` — certificate problems (DNS not pointing here, port 80 closed).
- `docker compose logs zammad-railsserver` — application errors.
- Microsoft sign-in fails with "redirect URI mismatch": the URI in step 3.1 must match exactly.
- Search finds nothing: `docker compose exec zammad-railsserver bundle exec rake zammad:searchindex:rebuild`.

## Later: connect the HR app (IIS)

When employees should also see and file tickets from the HR app:

1. Zammad: as an admin, avatar → Profile → **Token Access** → Create, permissions
   **admin.user**, **ticket.agent**, **admin.overview**; copy the token.
2. HR API `appsettings.Production.json`:
   `"Zammad": { "BaseUrl": "https://support.worldcraftlogistics.net", "ApiToken": "<token>" }`
3. IIS: the HR API's app pool **Start Mode = AlwaysRunning**, **Idle Time-out = 0**, site
   **Preload Enabled = True** (its department sync runs in the background).
4. Zammad: Admin → Overviews → **HR portal – open requests** → set it active (it is off while
   the HR app isn't connected, since only HR app tickets show in it).

From then on the HR app keeps Zammad's departments and employees' locations up to date, and
tickets filed in either place show in both.
