# Still working with documentation


# 🚀 Application Server Setup Guide

This guide explains how to set up the **application server** where your app will run.

---

## 1. Clone repository

git clone https://github.com/StealLine/DEVOPS_WORKFLOW_MICROSERVICES.git

cd DEVOPS_WORKFLOW_MICROSERVICES/application_server  

---

## 2. Prepare deployment script

Make the deployment script executable:

chmod +x deploy_script.sh  

⚠️ Ensure the user you are running commands with has sudo privileges.

---

## 3. Run deployment

Start the setup:

sudo ./deploy_script.sh  

---

## 4. Configure Traefik (Cloudflare)

Go to Traefik configuration directory:

sudo su

cd /home/deploy/deployVokimi/traefik  

Then set up Cloudflare credentials:

- Cloudflare email  
- Cloudflare API key (for the domain connected to your Cloudflare account)

These are required for SSL and domain routing.

---

## 5. Setup SSH access for CI

Navigate to SSH folder:

cd /home/deploy/.ssh  

Edit the authorized_keys file:

nano authorized_keys  

Add your public SSH key here so CI/CD can connect to the server.

---
