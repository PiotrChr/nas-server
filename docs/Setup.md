# Setup Basics — Pre‑Ansible Bootstrap

This document describes the **manual bootstrap phase** — the minimal system configuration required before Ansible can take over full automation.

---

## 1. Install Ubuntu Server

**Version:** Ubuntu Server 24.04 LTS (minimal installation)

**Steps:**

1. Create a bootable USB using the official ISO.
2. Boot from USB and install Ubuntu to the **Optane drive**.
3. Partition layout:

   ```
   /boot   ext4   1G
   /       ext4   remaining space
   ```
4. Select minimal install, disable snap packages when possible.
5. Create an administrative user (will be used by Ansible later).
6. Skip software selection; no additional packages yet.

---

## 2. Networking Configuration

Assign a **static IP** to the 10 GbE interface.

Example `/etc/netplan/01-netcfg.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: no
      addresses: [192.168.1.10/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1,8.8.8.8]
```

Apply:

```bash
sudo netplan apply
```

Verify with:

```bash
ip a
ping 1.1.1.1
```

---

## 3. Basic Packages

Install minimal dependencies for Ansible and ZFS:

```bash
sudo apt update
sudo apt install -y git curl python3 net-tools vim zfsutils-linux smartmontools ufw avahi-daemon
```

---

## 4. Storage Preparation

Identify drives:

```bash
lsblk -o NAME,SIZE,MODEL,MOUNTPOINT
```

Format and mount temporarily:

```bash
sudo mkfs.ext4 /dev/nvme0n1
sudo mkfs.ext4 /dev/sda
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /fast /bulk /archive
```

Add to `/etc/fstab` using UUIDs:

```bash
sudo blkid
sudo nano /etc/fstab
```

Example entries:

```
UUID=<uuid_nvme> /fast ext4 noatime 0 2
UUID=<uuid_sata> /bulk ext4 noatime 0 2
UUID=<uuid_hdd>  /archive ext4 noatime,nodiratime 0 2
```

Mount all:

```bash
sudo mount -a
```

Later, Ansible will reformat `/fast`, `/bulk`, and `/archive` as ZFS pools per configuration.

---

## 5. SSH Access for Ansible

1. Create an SSH keypair on your admin machine if you don’t have one:

   ```bash
   ssh-keygen -t ed25519 -C "ansible@nas"
   ```
2. Copy it to the server:

   ```bash
   ssh-copy-id user@192.168.1.10
   ```
3. Verify passwordless login:

   ```bash
   ssh user@192.168.1.10
   ```

---

## 6. Firewall Baseline (optional)

Basic UFW configuration:

```bash
sudo ufw allow 22/tcp
sudo ufw enable
sudo ufw status verbose
```

Ansible will later expand this with additional service rules.

---

## 7. Validate Before Automation

Checklist:

* [ ] SSH access confirmed
* [ ] Static IP functional
* [ ] All disks visible via `lsblk`
* [ ] `/fast`, `/bulk`, `/archive` mounted
* [ ] `sudo` works without password prompt (optional Ansible optimization)

Once all boxes are checked, proceed to `ansible/site.yml` and run the full automation process:

```bash
ansible-playbook -i ansible/inventory/hosts ansible/site.yml
```

This concludes the manual phase — from here, Ansible provisions Docker, Nomad, Samba, and monitoring automatically.
