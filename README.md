# DEVOPS_WORKFLOW_MICROSERVICES
*This devops workflow was built for the [Vokimi](https://github.com/StealLine/Voki_App_Project) application*
---

- **Application Server** — runs the app, Traefik reverse proxy, Dockhand exporter, and Grafana Alloy.
- **Tools Server** — runs Grafana, Prometheus, Loki, Alloy, SonarQube, Dockhand, and Traefik.

Both servers use Docker Compose stacks, managed under dedicated system users (`deploy` and `tools`) for isolation.

---
# №1 Setup your server/servers
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

# Application Server Setup (required)

---
### Setup Cloudflare according to your needs and set the correct subdomains for proper routing.

<img width="1146" height="256" alt="image" src="https://github.com/user-attachments/assets/887079fb-7558-48ee-8907-a3593fe85079" />

*Last one is root domain*

---

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
- Create Docker networks
- Create Docker volumes
  
```bash
Enter sudo su - deploy
```

## 6. Start monitoring (optional if you dont need metrics/logs)

```bash
cd /home/deploy/monitoring
docker compose up -d
```

## 7. Start the Dockhand exporter (optional)

```bash
nano /home/deploy/dockhand_exporter/compose.yml
```

Replace the placeholder with your VPS private IP (the one that shares a VPC with the [Tools Server](https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES#tools-server-setup-optional)):

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

## 8. Start Traefik

```bash
cd /home/deploy/deployVokimi/traefik
docker compose up -d
```


> **Note:** To send logs to a self-hosted Grafana instance, you need to expose the remote write endpoints for Prometheus and Loki on the Tools Server. Opening ports on a public IP is dangerous and not recommended — use a private IP instead. You can optionally add SSL certificates and basic auth so that even private network connections are secure. Your servers must be in same VPC to see each other!

---

# Tools Server Setup (optional)

## 1. Clone the repository

```bash
git clone https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES.git
rm -rf DEVOPS_WORKFLOW_MICROSERVICES/application_server
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

Also go to `/home/tools/compose.yml` and open required ports on your private IP for Prometheus and Loki:

**For Prometheus:**
```yaml
ports:
  - <your_tools_private_ip>:9090:9090
```

**For Loki:**
```yaml
ports:
  - <your_tools_private_ip>:3100:3100
```
    
## 4. Configure Alloy — where to send metrics and logs

```bash
nano tools/config.alloy
```

Same choice as on the app server — Grafana Cloud, self-hosted, or both.

To send to the **local** Prometheus and Loki running on this same server, uncomment the `local` blocks (or simply change them with your private ip of Tools_Server):

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
- Set file permissions 
- Copy all tool files to `/home/tools/`
- Create Docker networks
- Create Docker volumes


## 6. Start the main monitoring stack

```bash
sudo su - tools
cd /home/tools
docker compose up -d
```

This starts: **Grafana**, **Prometheus**, **Loki**, **Alloy**.

## 7. Start SonarQube (setup it manually by visiting sonarqube.yourdomain.com)

```bash
cd /home/tools/sonarqube
docker compose up -d
```

## 8. Start Dockhand (setup it manually by visiting dockhand.yourdomain.com)

```bash
cd /home/tools/dockhand
docker compose up -d
```
## 9. Start Traefik

```bash
cd /home/tools/traefik
docker compose up -d
```

> **Note:** Self-hosted Grafana and SonarQube are not enabled by default. The repository is self-explanatory enough that you should be able to figure it out. Keep in mind that Grafana, SonarQube, Prometheus, and Loki are resource-intensive — make sure your server meets the necessary hardware requirements.


# №2 — Set Up Your GitLab Repository

 > It is strongly recommended to read the README files for repositories before proceeding so you understand what each part does.
 
## Step 1: Create a GitLab Group
 
1. Log in to your GitLab instance.
2. Navigate to **Groups → New group**.
3. Give it a name and create the group.
---
 
## Step 2: Create the Application Repository
 
1. Inside the group, create a new project — name it whatever you like.
2. Clone the application source code from GitHub repo:
```bash
git clone https://github.com/StealLine/Voki_App_Project
```
 
3. Change the remote to point to your new GitLab repository:
```bash
cd Voki_App_Project
git remote set-url origin <your-gitlab-repo-url>
git push -u origin main
```
**If it is not allowing you to push to main directly, then unprotect main branch.**
**If git push -u origin main not working for you add --force option**

---
 
## Step 3: Create the CI/CD Configuration Repository
 
1. Inside the **same group**, create another new project for your CI/CD configuration.
2. Clone the CI/CD configuration from GitHub:
```bash
git clone https://github.com/StealLine/CI_CD_Configuration_Vokimi
```
 
3. Push it to the new GitLab repository:
```bash
cd CI_CD_Configuration_Vokimi
git remote set-url origin <your-gitlab-cicd-repo-url>
git push -u origin main
```
 
After this step, your GitLab group should contain two repositories — the application repo and the CI/CD configuration repo.

<img width="616" height="402" alt="image" src="https://github.com/user-attachments/assets/a33b14d0-db1d-4ea9-aada-43a95f2ec87c" />

---
 
## Step 4: Configure CI/CD Variables
 
Navigate to the **application repository** in GitLab, then go to:
 
**Settings → CI/CD → Variables**
 
Add the following variables. Unless you have a specific reason to restrict them, set each variable as **visible** and **not protected**.
 
### Server & Deployment
 
| Variable | Value / Description |
|---|---|
| `BASE_DIR_PATH` | `/home/deploy/deployVokimi` — unless you modified the [application server](https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES/tree/main#application-server-setup-required) script|
| `DEPLOY_HOST` | Public IP address of your server |
| `DEPLOY_USER` | `deploy` — unless you modified the [application server](https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES/tree/main#application-server-setup-required) script |
 
### Email (SMTP)
 
If you are not modifying the application code, use Resend as your SMTP provider — some values are hardcoded for it.  
Your domain must be registered in Resend. If you use Cloudflare DNS, Resend will prompt you to auto-configure all required DNS records.
 
| Variable | Value |
|---|---|
| `EMAIL_HOST` | `smtp.resend.com` |
| `EMAIL_PORT` | `587` |
| `EMAIL_USERNAME` | `onboarding@<your-domain>` |
| `EMAIL_PASSWORD` | Your Resend API key |
 
 

PRIVATE_K - Your **private SSH key**, Base64-encoded (base64 -w 0 <YourKey>). The corresponding **public key** must be added to the server as described in the [infrastructure setup guide](https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES/tree/main#2-add-your-cicd-ssh-public-key).

PROJECT_REF - The GitLab project reference path of the repository where your CI/CD configuration is stored.

JWT variables is just base64 encoded jwt keys, you can google how to generate them
 
 
The remaining variables are self-explanatory.
 
---
Your repo must have this variables

<img width="1207" height="698" alt="image" src="https://github.com/user-attachments/assets/b1d7c0a9-39ca-4672-a5ff-5d7891987dc0" />
<img width="1210" height="809" alt="image" src="https://github.com/user-attachments/assets/5a3c8917-ed0b-40d9-8d27-17ea0f181543" />

## S3 Bucket Configuration

The application requires an S3 bucket named **`vokimi-storage`** with the following structure:

```
vokimi-storage/
├── common/
│   ├── default-user-profile-pic.webp
│   └── default-voki-cover.webp
└── preset-profile-pics/
    ├── basic-black.webp
    ├── pets-marsita.webp
    ├── pets-ya-cat.webp
    ├── pets-zara.webp
    ├── pets-monika.webp
    ├── boykisser-1.webp
    ├── boykisser-2.webp
    ├── boykisser-3.webp
    ├── boykisser-4.webp
    ├── dasha-1.webp
    ├── dasha-2.webp
    ├── dasha-3.webp
    └── dasha-4.webp
```

> ⚠️ All files must be in `.webp` format. This structure is **required** for the application to work correctly.

The bucket layout should look like this:

<img width="674" height="622" alt="image" src="https://github.com/user-attachments/assets/6ec29025-00bc-4fdb-bfe7-f70e4c43e526" />

<img width="653" height="151" alt="image" src="https://github.com/user-attachments/assets/cec2fe07-db0f-4b83-be3c-fb09ae31b6e9" />

---

# CI/CD Pipeline — First-Time Setup

## Step 1 — Enable Display Variables

Make sure **Display pipeline variables** is enabled in the pipeline settings:

<img width="1260" height="285" alt="image" src="https://github.com/user-attachments/assets/ded0f6fa-e486-43ce-a838-559ff3a46d93" />

---

## Step 2 — Initialize the .NET Docker Image

Before running the pipeline for the first time, you need to pre-pull the .NET SDK image by triggering a **manual pipeline run from the `main` branch**.

### Steps

1. Open the pipeline manually
2. Set the `DOTNET` variable to:

```text
mcr.microsoft.com/dotnet/sdk:9.0-alpine
```

3. Click **Run pipeline**

At this stage, only **one initialization job** should appear.

<img width="760" height="573" alt="image" src="https://github.com/user-attachments/assets/2c105485-342e-44a5-a80e-ceb8900e6b88" />

---

Once the initialization run completes, the setup is finished.

You can now:

* Push changes normally
* Open merge requests
* Let the CI/CD pipeline handle builds, tests, deployments, and preview environments automatically

---

# SonarQube

If you configured a SonarQube instance during the [Tools Server Setup](https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES/tree/main#tools-server-setup-optional), you will receive the following variables from SonarQube:

* `SONAR_HOST_URL`
* `SONAR_TOKEN`

These variables are required for SonarQube analysis jobs.

---

# Backup Configuration

For correct backup behavior, you may need to set the `S3_REGION` environment variable or adjust commands inside containers related to backups.

Backup image repository:

* [postgres-backup-s3 repository](https://github.com/eeshugerman/postgres-backup-s3?utm_source=chatgpt.com)

---

# Trivy Scanning

If you want the Trivy security scan job to run automatically, you can create a **scheduled pipeline** depending on your preferred scanning frequency.

---

# Related Repositories

* [CI/CD Configuration Repository](https://github.com/StealLine/CI_CD_Configuration_Vokimi?utm_source=chatgpt.com)
* [Vokimi Application Repository](https://github.com/StealLine/Voki_App_Project?utm_source=chatgpt.com)

**Thanks for reading!**
