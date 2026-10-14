# Project 2: Docker Storage, Volume Persistence & Disaster Recovery

[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15_Alpine-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Storage](https://img.shields.io/badge/Storage-Named_Volumes-success)](#)
[![Backup](https://img.shields.io/badge/Disaster_Recovery-Automated_Sidecar-blue)](#)

A production-grade implementation of **Docker Stateful Storage Architecture**, **Volume Lifecycle Management**, and **Automated Disaster Recovery (DR)** for PostgreSQL. 

This project solves the "goldfish memory" problem of stateless containers by decoupling persistent data from container execution, proving complete data survival across container destruction, and automating hot volume snapshots using the **Ephemeral Sidecar Container Pattern**.

---

## 1. Executive Summary & Architecture Overview

By default, Docker containers are **stateless and ephemeral**. Any file written inside a container without a volume is stored in its temporary **writable layer** (managed by storage drivers like `overlay2`). When that container is updated, crashed, or terminated, all data inside that writable layer is permanently lost.

This project implements an enterprise **PostgreSQL 15 storage architecture** demonstrating:
1. **Docker Named Volumes** for high-performance, decoupled database persistence.
2. **Bind Mounts** for deterministic configuration and database seed initialization.
3. **Automated Disaster Simulation** proving 100% data survival across container deletion.
4. **Volume Backup & Disaster Recovery Pipelines** using disposable sidecar worker containers.

```
+-------------------------------------------------------------------------------+
|                                DOCKER HOST                                    |
|                                                                               |
|   +------------------------------------+   +------------------------------+   |
|   |         NAMED VOLUME               |   |          BIND MOUNT          |   |
|   |  postgres_data_project2            |   |  ./sql/init.sql              |   |
|   |  (/var/lib/docker/volumes/...)     |   |  (Sitting on Host Disk)      |   |
|   +-----------------+------------------+   +--------------+---------------+   |
|                     |                                     |                   |
+---------------------|-------------------------------------|-------------------+
                      | (High-Speed I/O)                    | (Read-Only :ro)   |
            +---------v-------------------------------------v---------+         |
            |              POSTGRESQL 15 ALPINE CONTAINER             |         |
            |                                                         |         |
            |  Mounted At: /var/lib/postgresql/data                   |         |
            |  Database Cluster: /var/lib/postgresql/data/pgdata      |         |
            |                                                         |         |
            |  Initialization: /docker-entrypoint-initdb.d/init.sql   |         |
            +---------------------------------------------------------+         |
```

---

## 2. The 3 Types of Docker Storage Compared

| Storage Type | Managed By | Host Location | Performance | Primary Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Named Volumes** | Docker Daemon | `/var/lib/docker/volumes/<name>/_data` | **Highest** (Bypasses storage driver) | Production databases, persistent caches, multi-container shared state |
| **Bind Mounts** | Host OS / User | Anywhere on host (e.g. `./sql/init.sql`, `./src`) | High | Development hot-reloading, mounting config files (`nginx.conf`) |
| **Tmpfs Mounts** | Host RAM | In-memory only (never touches physical disk) | Ultra-Fast | Transient sensitive secrets, session tokens, ephemeral cache |

---

## 3. Why Databases Must NOT Run on Container Layers (Overlay2 & CoW)

When a container writes to its own layer without a volume:
1. **Copy-on-Write (CoW) Penalty:** The `overlay2` storage driver must search through all image layers, copy the file up to the container's top writable layer, and then modify it. For write-heavy databases (PostgreSQL, MySQL, MongoDB), this introduces massive I/O latency and CPU overhead.
2. **Data Annihilation:** A simple `docker rm` wipes out the writable layer immediately.
3. **Volume Advantage:** Named volumes are mounted directly as native filesystem mounts from the host kernel. Database writes bypass `overlay2` completely, achieving near bare-metal disk throughput.

---

## 4. Repository Structure & Artifacts

```text
project-2-storage-volumes/
├── docker-compose.yml         # Defines PostgreSQL service, named volume & bind mount
├── sql/
│   └── init.sql               # Database schema & automated seed script
├── scripts/
│   ├── disaster-test.sh       # Automated test: writes data, kills container, verifies survival
│   ├── backup-volume.sh       # Automated logical SQL dump + physical volume .tar.gz snapshot
│   └── restore-volume.sh      # Automated disaster recovery: recreates volume from backup
└── README.md                  # Comprehensive architectural guide & interview prep
```

---

## 5. End-to-End Manual Testing Walkthrough

Use these commands to test the entire volume lifecycle manually on any Linux/macOS machine or Cloud VM with Docker installed.

### Step 1: Start the Database Service
```bash
docker compose up -d
```
**Verification Check:**
Wait 5 seconds and verify the database passed its healthcheck:
```bash
docker ps --filter "name=postgres-production-db"
```
*Expected Output:* Status shows `Up ... (healthy)`.

---

### Step 2: Run the Disaster Simulation Test
Execute the automated disaster test script:
```bash
chmod +x scripts/*.sh
./scripts/disaster-test.sh
```
**What happens during this test:**
1. Connects to database and reads seed accounts (`Avi Arora`, `DevOps Team Lead`).
2. Inserts a dynamic test record: `('Disaster Recovery Survivor', 777777.00)`.
3. Forcefully destroys the running container: `docker rm -f postgres-production-db`.
4. Checks `docker ps -a` to prove the container is completely deleted.
5. Re-launches a brand new container connected to the same named volume (`docker compose up -d`).
6. Queries the database: Record `#6` (`Disaster Recovery Survivor`) appears intact!

---

### Step 3: Run the Volume Backup Utility
Run the backup script to create on-demand snapshots:
```bash
./scripts/backup-volume.sh
```
**Expected Output:**
```text
[METHOD 1] Creating Logical SQL Dump using 'pg_dump'...
✓ Logical SQL backup created successfully!
  File: ./backups/enterprise_db_backup_20261014_123634.sql (5.7 KB)

[METHOD 2] Creating Raw Volume Tarball using Ephemeral Alpine Container...
✓ Raw volume tarball created successfully!
  File: ./backups/volume_postgres_data_project2_20261014_123634.tar.gz (6.5 MB)
```

---

### Step 4: Run the Disaster Recovery Restoration Test
Simulate catastrophic loss where someone accidentally deletes both the container **AND the volume** (`docker compose down -v`), then restore from backup:
```bash
./scripts/restore-volume.sh
```
**What happens during this test:**
1. Destroys the container and wipes `postgres_data_project2` from disk.
2. Creates a clean, empty volume: `docker volume create postgres_data_project2`.
3. Spins up a temporary Alpine worker that unpacks the latest `.tar.gz` archive into the volume.
4. Starts the PostgreSQL container on the restored volume.
5. Queries `customer_accounts` to prove all accounts and balances are 100% recovered!

---

## 6. How to Automate & Schedule Backups in Production

In real-world enterprise environments, you don't run backup scripts manually. You automate them using one of the following production patterns.

### Option A: Standard Linux Cron Job (Virtual Machines & Bare-Metal)

On an Ubuntu / Debian / RHEL host running Docker, configure a root cron job:

1. Open root crontab:
   ```bash
   sudo crontab -e
   ```
2. Schedule the backup script to run every night at **02:00 AM UTC** (off-peak hours):
   ```cron
   # Minute Hour Day Month DayOfWeek Command
   0 2 * * * /home/ubuntu/project-2-storage-volumes/scripts/backup-volume.sh >> /var/log/docker-backups.log 2>&1
   ```
3. **Log Rotation Setup:** Prevent `/var/log/docker-backups.log` from filling the disk by creating `/etc/logrotate.d/docker-backups`:
   ```text
   /var/log/docker-backups.log {
       weekly
       rotate 4
       compress
       missingok
       notifempty
   }
   ```

---

### Option B: Cloud-Native Automation (AWS S3 + Systems Manager)

In enterprise cloud setups, backups must be stored **off-server** in an object store so that a lost server doesn't take your backups with it.

#### 1. Integrate S3 Upload into `backup-volume.sh`:
Add these lines to the end of `scripts/backup-volume.sh`:
```bash
# Upload to Encrypted AWS S3 Bucket
S3_BUCKET="s3://my-enterprise-db-backups-bucket/postgres"
echo "Uploading backup to AWS S3: ${S3_BUCKET}..."

aws s3 cp "${BACKUP_DIR}/${TAR_BACKUP_FILE}" "${S3_BUCKET}/${TAR_BACKUP_FILE}" --sse aws:kms
aws s3 cp "${SQL_BACKUP_FILE}" "${S3_BUCKET}/$(basename ${SQL_BACKUP_FILE})" --sse aws:kms

# Delete local backups older than 7 days to conserve disk space
find "${BACKUP_DIR}" -type f -name "volume_*" -mtime +7 -delete
find "${BACKUP_DIR}" -type f -name "enterprise_db_*" -mtime +7 -delete
```

#### 2. Schedule via AWS EventBridge & SSM:
Instead of relying on an on-box cron daemon, use AWS native scheduling:
1. **AWS EventBridge Rule:** Fires a cron expression (e.g., `cron(0 2 * * ? *)`).
2. **Target (AWS Systems Manager Run Command):** Invokes the script on the target EC2 instances without requiring open SSH ports or hardcoded SSH keys.
3. **IAM Role:** The EC2 instance uses an attached IAM Instance Profile with `s3:PutObject` permissions (zero hardcoded AWS credentials).

---

### Option C: Automated Failure Alerting (Slack / Webhook Notification)

If a backup fails, your DevOps team must be notified immediately. Wrap the backup execution with an alerting trap:

```bash
# Add to scripts/backup-volume.sh
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

send_slack_alert() {
    local message="$1"
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 *DATABASE BACKUP FAILED*: ${message}\"}" \
        "${SLACK_WEBHOOK_URL}"
}

# Trap unexpected errors and trigger alert
trap 'send_slack_alert "Backup failed at line $LINENO on host $(hostname)"' ERR
```

---

## 7. Senior DevOps Interview Questions & Production War Stories

### Q1: What is the technical difference between a Named Volume and a Bind Mount?
> **Answer:** 
> * **Named Volumes** are completely isolated and managed by Docker under `/var/lib/docker/volumes/`. They are filesystem-agnostic, have higher I/O performance (no host filesystem permission quirks), and can be shared safely across containers.
> * **Bind Mounts** point to a specific host folder (like `./src`). They depend on the host operating system's directory structure, and their file permissions (UID/GID) are tied directly to the host user. Bind mounts are best for injecting config files (`nginx.conf`) or source code during local development.

### Q2: Why is storing database files inside the container's writable layer an anti-pattern?
> **Answer:**
> Beyond the obvious risk of data loss on container deletion, there is a severe **performance penalty**. Container writable layers use union filesystems (like `overlay2`) which implement **Copy-on-Write (CoW)**. Every write requires the storage driver to locate the block in lower layers, copy it to the top layer, and modify it. For a database with heavy random writes and transaction logs (WAL), this causes severe disk I/O bottlenecks. Named volumes bypass `overlay2` and write directly to host storage at native speed.

### Q3: How do you back up a Docker named volume without installing extra backup tools on the host?
> **Answer:**
> We use the **Disposable Sidecar Container Pattern**. We run a lightweight Alpine container (`docker run --rm`) with two volume mounts: the named volume mounted as **read-only** (`:ro`) and a host backup directory. Inside the Alpine container, we execute `tar -czf` to archive the volume data into the backup directory. Once the archive is created, the temporary container automatically self-terminates, leaving zero footprint on the host.

### Q4: What happens if two containers mount the same named volume simultaneously?
> **Answer:**
> Docker allows multiple containers to mount the same named volume concurrently. However, Docker does **not** provide distributed file locking. If two containers write to the same files at the same time, file corruption can occur unless the application layer (or a clustered filesystem) manages concurrent access. For read-heavy shared data (like static media or configuration assets), sharing volumes is completely safe.

### Q5: What is the `lost+found` issue in PostgreSQL Docker volumes, and how do you prevent it?
> **Answer:**
> In Linux ext4 filesystems, the root of a mounted volume contains a system folder called `lost+found`. When the official PostgreSQL container initializes (`initdb`), it expects the target directory to be 100% empty. If it sees `lost+found`, `initdb` crashes. The production solution is setting the `PGDATA` environment variable to a subfolder within the mount: `PGDATA=/var/lib/postgresql/data/pgdata`. This ensures PostgreSQL creates and owns a dedicated subfolder, completely avoiding conflicts.
