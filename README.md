> ⚠️ **Work in progress** — documentation and project are still being developed.

# DEVOPS_WORKFLOW_MICROSERVICES

- **Application Server** — runs the app, Traefik reverse proxy, Dockhand exporter, and Grafana Alloy.
- **Tools Server** — runs Grafana, Prometheus, Loki, Alloy, SonarQube, Dockhand, and Traefik.

Both servers use Docker Compose stacks, managed under dedicated system users (`deploy` and `tools`) for isolation.

---

## Architecture overview

Alloy on the **application server** ships metrics and logs to Prometheus and Loki on the **tools server** (or to Grafana Cloud — see `config.alloy` comments).  
Alloy on the **tools server** monitors the tools server itself the same way and can optionally send metrics to Grafana Cloud as well.

---

## Repository structure

```
.
├── application_server/
│   ├── deploy_script.sh                  # Bootstrap script — run once on the app server
│   └── deploy/
│       ├── .ssh/
│       │   └── authorized_keys           # ⚠️ Add your CI/CD public key here before running
│       ├── deployVokimi/
│       │   ├── traefik/
│       │   │   ├── .env                  # ⚠️ Fill in CF_API_EMAIL and CF_DNS_API_TOKEN from Cloudflare
│       │   │   ├── compose.yml
│       │   │   └── letsencrypt/
│       │   │       └── acme.json
│       │   ├── deploy/                   # Production compose file and its necessary components
│       │   └── preview/                  # Preview apps go here
│       ├── dockhand_exporter/
│       │   └── compose.yml               # ⚠️ Set private IP and TOKEN before starting
│       └── monitoring/
│           ├── compose.yml               # Alloy collector for the app server
│           └── config.alloy              # ⚠️ Configure Loki/Prometheus destinations
│
└── tools_server/
    ├── tools_deploy.sh                   # Bootstrap script — run once on the tools server
    └── tools/
        ├── compose.yml                   # Main stack: Grafana, Prometheus, Loki, Alloy
        ├── config.alloy                  # ⚠️ Configure Loki/Prometheus destinations
        ├── loki-config.yml               # Loki storage config
        ├── prometheus/
        │   └── prometheus.yml            # Prometheus scrape config
        ├── grafana/
        │   └── provisioning/
        │       ├── datasources/
        │       │   └── ds.yml            # Prometheus + Loki datasources (auto-provisioned)
        │       ├── dashboards/           # Pre-configured dashboards — feel free to customise
        │       │   ├── dashboard_provider.yml
        │       │   └── VokiMonitoring/
        │       │       ├── docker_dashboard.json
        │       │       ├── hardware_dashboard.json
        │       │       └── logs.json
        │       └── alerting/             # Pre-configured alerts — feel free to customise
        │           ├── docker_alerts.yml
        │           └── host_alerts.yml
        ├── traefik/
        │   ├── .env                      # ⚠️ Fill in CF_API_EMAIL and CF_DNS_API_TOKEN
        │   ├── compose.yml
        │   └── letsencrypt/
        │       └── acme.json
        ├── dockhand/
        │   └── compose.yml               # Dockhand UI for Docker management
        └── sonarqube/
            └── compose.yml               # SonarQube (not configured by default)
```

---

# Application Server Setup

## 1. Clone the repository

```bash
git clone https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES.git
rm -rf DEVOPS_WORKFLOW_MICROSERVICES/tools_server
cd DEVOPS_WORKFLOW_MICROSERVICES/application_server
```

## 2. Add your CI/CD SSH public key

Before running anything, add the public key that your CI/CD pipeline will use to connect:

```bash
nano deploy/.ssh/authorized_keys
# Replace the placeholder with your actual public key, e.g.:
# ssh-ed25519 AAAAC3Nza... ci-user@github
```

## 3. Fill in Traefik / Cloudflare credentials

```bash
nano deploy/deployVokimi/traefik/.env
```

```env
CF_API_EMAIL=your@email.com
CF_DNS_API_TOKEN=your_cloudflare_api_token
```

The token requires `Zone:DNS:Edit` permissions for the domain you want to use.

## 4. Configure Alloy — where to send metrics and logs

```bash
nano deploy/monitoring/config.alloy
```

By default, Alloy is configured for **Grafana Cloud**. To send to your own Tools Server instead, uncomment the `local` blocks:

```alloy
// Uncomment and fill in your Tools Server IP or hostname:
loki.write "local" {
  endpoint {
    url = "http://<TOOLS_SERVER_IP>:3100/loki/api/v1/push"
  }
}

prometheus.remote_write "local" {
  endpoint {
    url = "http://<TOOLS_SERVER_IP>:9090/api/v1/write"
  }
}
```

Then, in each `forward_to` block, uncomment the local receiver.

## 5. Run the bootstrap script

```bash
chmod +x deploy_script.sh
./deploy_script.sh
```

This will:
- Install Docker and Docker Compose
- Create the `deploy` system user
- Copy all deploy files to `/home/deploy/`
- Set correct file ownership
- Create Docker networks: `preview_deploy`, `production_deploy`, `monitor-net`
- Create Docker volume: `alloy_data`

## 6. Start Traefik

```bash
sudo su - deploy
cd /home/deploy/deployVokimi/traefik
docker compose up -d
```

## 7. Start monitoring (Alloy)

```bash
cd /home/deploy/monitoring
docker compose up -d
```

## 8. Start the Dockhand exporter

```bash
nano /home/deploy/dockhand_exporter/compose.yml
```

Replace the placeholder with your VPS private IP (the one that shares a VPC with the Tools Server):

```yaml
ports:
  - "192.168.0.5:2376:2376"   # use your actual private IP
```

Also set a secure token:

```yaml
environment:
  TOKEN: your_secure_token_here
```

Then start it:

```bash
cd /home/deploy/dockhand_exporter
docker compose up -d
```

> **Note:** To send logs to a self-hosted Grafana instance, you need to expose the remote write endpoints for Prometheus and Loki on the Tools Server. Opening ports on a public IP is dangerous and not recommended — use a private IP instead. You can optionally add SSL certificates and basic auth so that even private network connections are secure.

---

# Tools Server Setup

## 1. Clone the repository

```bash
git clone https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES.git
cd DEVOPS_WORKFLOW_MICROSERVICES/tools_server
```

## 2. Fill in Traefik / Cloudflare credentials

```bash
nano tools/traefik/.env
```

```env
CF_API_EMAIL=your@email.com
CF_DNS_API_TOKEN=your_cloudflare_api_token
```

## 3. Set your domain names

In the following files, replace `yourdomain` with your actual domain:

**`tools/compose.yml`** — Grafana label:
```yaml
- "traefik.http.routers.grafana.rule=Host(`grafana.yourdomain.com`)"
```

**`tools/sonarqube/compose.yml`** — SonarQube label:
```yaml
- "traefik.http.routers.sonar.rule=Host(`sonarqube.yourdomain.com`)"
```

**`tools/dockhand/compose.yml`** — Dockhand label:
```yaml
- "traefik.http.routers.dockhand.rule=Host(`dockhand.yourdomain.com`)"
```

## 4. Configure Alloy — where to send metrics and logs

```bash
nano tools/config.alloy
```

Same choice as on the app server — Grafana Cloud, self-hosted, or both.

To send to the **local** Prometheus and Loki running on this same server, uncomment the `local` blocks:

```alloy
loki.write "local" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

prometheus.remote_write "local" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}
```

Then in each `forward_to` block, replace `grafanacloud` with `local`.

## 5. Run the bootstrap script

```bash
chmod +x tools_deploy.sh
./tools_deploy.sh
```

This will:
- Install Docker and Docker Compose
- Create the `tools` system user
- Set file permissions (755 for dirs, 644 for files, 600 for `acme.json`)
- Copy all tool files to `/home/tools/`
- Create Docker networks: `monitor-net`, `dockhand`, `sonarnet`
- Create Docker volumes: `prom_data`, `loki_data`, `alloy_data`, `grafana_data`

## 6. Start Traefik

```bash
sudo su - tools
cd /home/tools/traefik
docker compose up -d
```

## 7. Start the main monitoring stack

```bash
cd /home/tools
docker compose up -d
```

This starts: **Grafana**, **Prometheus**, **Loki**, **Alloy**.

## 8. Start SonarQube (optional)

```bash
cd /home/tools/sonarqube
docker compose up -d
```

## 9. Start Dockhand (optional)

```bash
cd /home/tools/dockhand
docker compose up -d
```

---

Don't forget to configure Cloudflare according to your needs and set the correct subdomains for proper routing.

![Cloudflare DNS example](https://github.com/user-attachments/assets/22afbb4f-9a42-4d03-b795-b911751af0ec)

> **Note:** Self-hosted Grafana and SonarQube are not enabled by default. The repository is self-explanatory enough that you should be able to figure it out. Keep in mind that Grafana, SonarQube, Prometheus, and Loki are resource-intensive — make sure your server meets the necessary hardware requirements.
