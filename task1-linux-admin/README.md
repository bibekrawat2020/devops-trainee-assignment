# Task 1: System Provisioning & Linux Administration

## Overview

This document covers the setup of an Ubuntu cloud instance deployed from AWS EC2, with a dedicated sudo user, hardened SSH access (key-based authentication on port 2222), and a configured UFW firewall.

## Environment: 
- Platform: AWS
- OS: Ubuntu Resolute 26.04


## Step 1: Connect to the Server
Connect to your instance using the provided `.pem` key:

```bash
ssh -i assignment_server.pem ubuntu@<server-ip>
```

## Step 2: Create a Dedicated User with Sudo Privileges
Create the dedicated user "trainee" and assigning the trainee user with sudo privileges
```bash
sudo adduser trainee

sudo usermod -aG sudo trainee

```
## Verification
Verify the user trainee has been created or not. 
```bash
sudo su trainee

sudo whoami

id trainee

```
![Verification of user](screenshots/User%20Verification.png)

## Step 3: Configure Key-Based SSH Authentication

### 3a. Setup up SSH key auth for trainee
On local machine, we generate a ssh-key so that we can add the public key in trainee.
```bash
ssh-keygen -t ed25519 -C "trainee@devops-assignment" -f trainee_key
```
On ubuntu, we configure the ssh for trainee
```bash
sudo mkdir -p /home/trainee/.ssh
sudo nano /home/trainee/.ssh/authorized_keys
sudo chmod 700 /home/trainee/.ssh
sudo chmod 600 /home/trainee/.ssh/authorized_keys
sudo chown -R trainee:trainee /home/trainee/.ssh
```
### 3b. Change SSH port to 2222 and Disable root login
We eidt the SSh daemon configuration:
```bash
sudo nano /etc/ssh/sshd_config
```
We locate and update the following lines:
```
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```
Save the file, then restart SSH:
```bash
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh.service
```

## 4. Configure AWS Security Group
We add port 2222, port 80 for http and 443 for https in security group of EC2
Console → EC2 → Instance → Security → Security Group → Edit inbound rules:
- Added: Custom TCP 2222, source my-IP/32
- Confirmed: HTTP 80, HTTPS 443 open
- Removed: default SSH 22 rule (once 2222 confirmed working)

## Step 5: Configure UFW Firewall
Install UFW if not already present

```bash
sudo apt update && sudo apt install -y ufw
```
Set default policies
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```
Allow only the required ports
```bash
sudo ufw allow 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp  comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```
Enable the firewall
```bash
sudo ufw enable
```
Check status
```bash
sudo ufw status verbose
```
## Verification
![SSH Verify](screenshots/SSH%20Verify.png)
![UFW Status](screenshots/UFW%20Status.png)
![AWS Security Group](screenshots/AWS%20Security%20Group.png)
