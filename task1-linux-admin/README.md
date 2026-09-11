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

## Issues Encountered & Resolutions

### 1. SSH key permission errors on Windows
**Error:** Bad permissions. Try removing permissions for user: NT AUTHORITY\Authenticated Users
...
Permissions for 'assignment_server.pem' are too open.
Load key "assignment_server.pem": bad permissions
ubuntu@<ip>: Permission denied (publickey).

**Cause:** Windows doesn't use POSIX file permissions like Linux (`chmod`), so
OpenSSH on Windows checks NTFS ACLs instead. The `.pem` file had inherited
broad access (Administrators, SYSTEM, Authenticated Users, Users) — SSH
refuses to load a private key that other accounts can read.

**Additional complication:** the file was on a mapped network drive (`B:\`),
where `icacls` changes did not reliably persist.

**Resolution:**
```cmd
icacls assignment_server.pem /reset
icacls assignment_server.pem /inheritance:r
icacls assignment_server.pem /grant:r "%username%":R
```
Moving the key to a local path (`C:\Users\<user>\.ssh\`) resolved it
permanently after the network-drive version kept reverting.

---

### 2. SSH still listening on port 22 after editing sshd_config
**Symptom:** Changed `Port 2222` in `/etc/ssh/sshd_config` and restarted
`ssh.service`, but the server was still reachable on port 22 and not on 2222.

**Cause:** Ubuntu 22.04+ ships SSH as socket-activated by default
`ssh.socket` binds port 22 directly and hands connections to `ssh.service`,
independent of the `Port` directive in `sshd_config`. Editing the config file
alone has no effect while the socket unit is active.

**Resolution:**
```bash
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl enable --now ssh.service
sudo ss -tlnp | grep ssh  
```
Verified the new port worked in a second terminal session before closing
the original one.

### 3. Instance underpowered (t2.nano)
**Symptom:** Instance was noticeably slow once multiple containers were
expected to run.

**Cause:** t2.nano has only 0.5 GB RAM, insufficient for Nginx + Flask +
PostgreSQL (+ optional monitoring stack).

**Resolution:** Resized to a larger instance type; also considered adding a
swap file as a stopgap. Attached an Elastic IP first so the public IP
wouldn't change when the instance was stopped for resizing (Elastic IPs are
free while attached to a running instance).