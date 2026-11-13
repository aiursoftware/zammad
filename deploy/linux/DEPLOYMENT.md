# WCL Zammad — Deployment Guide

Step-by-step guide for a fresh install, redeploying on the existing server, and redeploying from
an existing installation (backup or move to a new server).

## 1. Overview

This guide deploys the WCL build of Zammad (the support-ticket system) on its own Linux server with
HTTPS. Employees sign in with their **Microsoft 365** account and create tickets directly in Zammad.
The HR app stays on IIS and is not part of this deployment.

```text
Employees & agents ──HTTPS──►  support.worldcraftlogistics.net   (Linux server)
  (Microsoft 365 sign-in)        Caddy :443  →  Zammad (nginx, rails, websocket, scheduler)
                                 PostgreSQL · Redis · Memcached · Elasticsearch · nightly backup
```

Everything runs in Docker. The deploy files live in the repository under `deploy/linux/`:

| File                 | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `docker-compose.yml` | All services: Zammad, database, cache, search, Caddy (HTTPS), backup     |
| `.env.example`       | Settings template. Copy it to `.env` (never commit `.env`)               |
| `build.sh`           | Builds the Zammad image from the checked-out code                        |
| `Caddyfile`          | HTTPS proxy. Gets the Let's Encrypt certificate automatically            |
| `verify.rb`          | Health check of everything WCL needs. Run it after each deploy           |

### Server requirements

|         | Recommended                                 | Minimum                  |
| ------- | ------------------------------------------- | ------------------------ |
| OS      | Ubuntu 24.04 LTS                            | Debian 12 / Ubuntu 22.04 |
| CPU     | 4 vCPU                                      | 2 vCPU                   |
| RAM     | 8 GB                                        | 6 GB                     |
| Disk    | 80 GB **SSD**                               | 40 GB                    |
| Network | Public IP, DNS A record, ports 80 + 443 open |                         |

The server needs outbound internet access to Let's Encrypt, Microsoft (login), Docker Hub, GitHub
and your mail server.

## 2. Fresh install (new server)

Run every command over SSH on the Linux server. Paste **one block at a time** and check its output
before you go on. When `sudo` asks for a password, type your own user's password. Nothing shows on
screen while you type.

### Step 1 — Install Docker and give your user access

```bash
sudo apt update && sudo apt install -y ca-certificates curl git
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
exit
```

SSH back in so the new group applies, then check:

```bash
docker ps            # must print an empty table, NOT "permission denied"
docker compose version
```

### Step 2 — Prepare the host

Elasticsearch needs this kernel setting (once):

```bash
echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-elasticsearch.conf && sudo sysctl --system
```

If the `ufw` firewall is active, open the ports:

```bash
sudo ufw allow 22,80,443/tcp
```

### Step 3 — DNS

Create an **A record** `support.worldcraftlogistics.net` → the server's public IP. Check it from the
server:

```bash
getent hosts support.worldcraftlogistics.net   # must show the server's public IP
```

> Do this before the first start. Caddy needs DNS and port 80 to get the HTTPS certificate.

### Step 4 — Get the code

```bash
cd ~ && git clone -b develop https://github.com/aiursoftware/zammad.git
cd ~/zammad/deploy/linux
```

If the repository is private, git asks for a login. Use your GitHub username and a **personal
access token** as the password.

### Step 5 — Configure

```bash
cp .env.example .env
openssl rand -base64 24        # copy this output
nano .env
```

In `.env`, set:

- `POSTGRES_PASSWORD=` the generated value. **Store it in the password manager.** You need it to
  restore backups.
- `ZAMMAD_FQDN=support.worldcraftlogistics.net`
- Leave the rest as is. Save with **Ctrl+O, Enter, Ctrl+X**.

### Step 6 — Build the image

```bash
chmod +x build.sh
./build.sh                     # 15–25 minutes the first time
```

### Step 7 — Start

```bash
docker compose up -d
docker compose logs -f zammad-init     # first run ~5 min; Ctrl+C once it has exited
docker compose ps
```

Every service should be **running**, and `zammad-init` should show **exited (0)**.

### Step 8 — Setup wizard

Open **<https://support.worldcraftlogistics.net>** in a browser and complete the wizard:

1. Create your admin account.
2. Set the organization name.
3. Set up the **email channel**. Notifications and the admin password-login link depend on it.

### Step 9 — Verify

```bash
docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb
```

All checks must pass (every line starts with PASS). The check cleans up after itself and leaves no data behind.

## 3. First-time configuration

Do this once, in the Zammad web UI, as the admin.

### Groups

Go to **Admin → Groups**:

- Create one group per team (HR, IT, Payroll, Maintenance, …).
- Tick **Customers can create tickets here** only for the groups employees may pick.
- Leave it off for teams that tickets are only handed to (Dev, Network).
- **Untick it on the built-in "Users" group**, which has it on by default.

### Agents

Go to **Admin → Users → New**, with the role **Agent**. Every agent automatically gets access to each
new group.

### Departments

Go to **Admin → Objects → User → Department**. Add your department names; employees pick their
department from this list.

### Microsoft 365 sign-in

In the Azure portal (an M365 admin does this):

1. **Microsoft Entra ID → App registrations → New registration**
   - Name: `WCL Support (Zammad)`
   - Supported account types: **this organizational directory only (single tenant)**
   - Redirect URI: **Web** →
     `https://support.worldcraftlogistics.net/auth/microsoft_office365/callback`
2. On the app's **Overview** page, copy the **Application (client) ID** and the **Directory (tenant) ID**.
3. **Certificates & secrets → New client secret** (24 months). Copy the **Value** right away, because
   it is shown only once. Add a calendar reminder to renew it.
4. **API permissions** → Microsoft Graph, delegated **User.Read, openid, email, profile** →
   **Grant admin consent**.

In Zammad:

- **Admin → Settings → Security → Third-party Applications → Authentication via Microsoft**: switch
  it on, paste the App ID, App Secret and Tenant ID, and save.
- Test it in a private browser window with **Sign in with Microsoft**. The employee should land in
  Zammad as a customer.
- Then go to **Security → Base** and turn off:
  - **Register as a new customer**
  - **Show password login**

  Admins can still sign in through _"Request the password login here"_ (an emailed link).

## 4. Redeploy on the existing server (keep all data)

Use this whenever new code has been pushed to GitHub. Tickets, users and settings stay. The
database lives in Docker volumes that a rebuild doesn't touch.

### 4.1 Update to the latest code

```bash
cd ~/zammad/deploy/linux

# 1. Safety backup first (DB + files into ./backup)
docker compose run --rm -e BACKUP_ONCE=true zammad-backup

# 2. Keep the current image so you can roll back
docker tag wcl/zammad:latest wcl/zammad:previous

# 3. Get the new code and build it
git pull
./build.sh

# 4. Restart on the new image (zammad-init runs the database migrations)
docker compose up -d
docker compose logs -f zammad-init     # Ctrl+C once it has exited

# 5. Check
docker compose ps
docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb
```

Downtime is about 1–2 minutes during step 4. The build in step 3 runs while the old version keeps
serving.

### 4.2 Redeploy the same version (restart only)

Use this after editing `.env`, or when something looks stuck:

```bash
cd ~/zammad/deploy/linux
docker compose up -d            # applies .env changes, recreates only what changed
docker compose restart          # or: restart everything as is
```

### 4.3 Re-apply the WCL setup

The WCL setup creates the Rejected state, the Urgent priority, the Owners field, the departments,
attachment settings and 30-day sessions. It is safe to run any time:

```bash
docker compose exec zammad-railsserver bundle exec rails zammad:wcl:setup
```

### 4.4 Roll back to the previous version

If the new version misbehaves:

```bash
cd ~/zammad/deploy/linux
sed -i 's|^IMAGE=.*|IMAGE=wcl/zammad:previous|' .env
docker compose up -d
```

> If the update included database migrations, also restore the safety backup from step 4.1 (see
> **5.2**). Once the fix is pushed, set `IMAGE=wcl/zammad:latest` again and redeploy with 4.1.

## 5. Redeploy from an existing installation

A backup is two files in `~/zammad/deploy/linux/backup/`, taken at the same time:

- `<timestamp>_zammad_db.psql.gz` — the database (tickets, users, settings)
- `<timestamp>_zammad_files.tar.gz` — the file storage

### 5.1 Move to a new server (or rebuild a broken one)

On the **old** server, take a fresh backup and copy it over:

```bash
cd ~/zammad/deploy/linux
docker compose run --rm -e BACKUP_ONCE=true zammad-backup
ls -lt backup | head -3                     # the newest pair
scp backup/<timestamp>_zammad_* itadmin@NEW_SERVER:~/
scp .env itadmin@NEW_SERVER:~/zammad.env
```

On the **new** server:

1. Do section 2, steps 1–4: Docker, host prep and clone. Don't switch DNS yet.
2. Reuse the old settings:

   ```bash
   cp ~/zammad.env ~/zammad/deploy/linux/.env
   ```

3. Build and start (section 2, steps 6–7). **Skip the setup wizard**, because the restore brings the
   old admin and settings back.
4. Restore the backup:

   ```bash
   cd ~/zammad/deploy/linux
   mkdir -p backup/restore && mv ~/*_zammad_* backup/restore/
   docker compose stop zammad-railsserver zammad-scheduler zammad-websocket zammad-backup
   docker compose run --rm zammad-backup          # restores the newest pair, then prints "Restore completed."
   docker compose up -d
   docker compose exec zammad-railsserver bundle exec rails zammad:searchindex:rebuild
   ```

5. Point the DNS A record at the new server's IP. Caddy then gets the certificate within a minute.
6. Run `verify.rb` (section 2, step 9), log in and check a few tickets.
7. Stop the old server's stack: `docker compose down`. Keep its data until you're sure.

### 5.2 Restore a backup on the same server

Use this to undo a bad update, or to go back to last night:

```bash
cd ~/zammad/deploy/linux
ls -lt backup | head                                     # pick the pair to restore
mkdir -p backup/restore
cp backup/<timestamp>_zammad_* backup/restore/
docker compose stop zammad-railsserver zammad-scheduler zammad-websocket zammad-backup
docker compose run --rm zammad-backup
docker compose up -d
docker compose exec zammad-railsserver bundle exec rails zammad:searchindex:rebuild
```

> ⚠️ A restore **replaces** the current database. Everything created after that backup is lost.

### 5.3 Full reset (start completely from scratch)

This **deletes all tickets, users and settings**. Only use it on a test install, or if you have a
backup you mean to restore.

```bash
cd ~/zammad/deploy/linux
docker compose down -v          # -v removes the data volumes
docker compose up -d            # fresh database, then the setup wizard again
```

The `./backup` folder is not a Docker volume, so it survives this.

## 6. Backups, operations and troubleshooting

### Backups

- **Automatic:** every night at 03:00, into `~/zammad/deploy/linux/backup`. Backups are kept for
  14 days.
- **On demand:** `docker compose run --rm -e BACKUP_ONCE=true zammad-backup`
- **Off-site:** a backup on the same disk doesn't survive a dead server. Copy the folder off the
  server regularly, for example nightly with `rsync` or `rclone` to another machine or to cloud
  storage.
- Keep `.env` (it holds `POSTGRES_PASSWORD`) in the password manager.

### Everyday commands

Run all of these from `~/zammad/deploy/linux`.

| Task                        | Command                                                                              |
| --------------------------- | ------------------------------------------------------------------------------------ |
| Status of all services      | `docker compose ps`                                                                  |
| Follow the app's log        | `docker compose logs -f zammad-railsserver`                                          |
| Restart everything          | `docker compose restart`                                                             |
| Stop everything (data kept) | `docker compose down`                                                                |
| Start everything            | `docker compose up -d`                                                               |
| Health check                | `docker compose exec -T zammad-railsserver bundle exec rails r - < verify.rb`        |
| Rebuild search index        | `docker compose exec zammad-railsserver bundle exec rails zammad:searchindex:rebuild` |
| Free disk from old images   | `docker image prune -f`                                                              |
| Disk usage                  | `df -h` and `docker system df`                                                       |

### Troubleshooting

| Symptom | Fix |
| --- | --- |
| `permission denied while trying to connect to the docker API` | Your user isn't in the docker group yet. Run `sudo usermod -aG docker $USER`, then **log out and SSH back in**. |
| `sudo: a password is required` | You pressed Enter without typing. Type your password; it stays invisible as you type. |
| `is not in the sudoers file` | The account has no admin rights. Ask whoever set up the server to run `usermod -aG docker <user>` as root. |
| Browser shows a certificate error / site not reachable | Check `docker compose logs caddy`. Usually DNS doesn't point at the server yet, or port 80/443 is closed. |
| `zammad-init` keeps restarting | Check `docker compose logs zammad-init`. Most often `POSTGRES_PASSWORD` was changed after the first start. Put the original value back. |
| Elasticsearch exits right away | The `vm.max_map_count` step (section 2, step 2) is missing. Run it, then `docker compose up -d`. |
| Search finds nothing | Rebuild the search index (see the table above). |
| Microsoft sign-in: "redirect URI mismatch" | The redirect URI in Azure must match exactly: `https://support.worldcraftlogistics.net/auth/microsoft_office365/callback` |
| `./build.sh: Permission denied` | Run `chmod +x build.sh` |
| Build fails with "no space left on device" | Run `docker builder prune -f && docker image prune -f`, then try again |

If a step fails, copy the full error output (or a screenshot) and send it to the developer.
