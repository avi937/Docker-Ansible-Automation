# Project 2: Docker Storage, Volume Persistence & Disaster Recovery

## 1. Executive Summary & Architecture Overview

By default, Docker containers are **stateless and ephemeral**. Any file written directly inside a container is stored in its temporary **writable layer** (managed by storage drivers like `overlay2`). When that container is stopped, updated, or destroyed, all data inside that writable layer is permanently lost.

This project implements an enterprise-grade **PostgreSQL 15 storage architecture** demonstrating:
1. **Docker Named Volumes** for high-performance, decoupled database persistence.
2. **Bind Mounts** for deterministic configuration and database seed initialization.
3. **Automated Disaster Simulation** proving 100% data survival across container destruction.
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

## 5. Quickstart & Execution Walkthrough

### Step 1: Launch the Database Stack
```bash
docker compose up -d
```
Verifies that:
* Volume `postgres_data_project2` is created.
* `./sql/init.sql` is mounted as read-only and automatically executed.
* Container status becomes `healthy` via `pg_isready`.

### Step 2: Run the Automated Disaster Simulation
```bash
chmod +x scripts/*.sh
./scripts/disaster-test.sh
```
**What this proves:**
1. Connects to database and queries seed accounts (`Avi Arora`).
2. Inserts a dynamic survivor record: `('Disaster Recovery Survivor', 777777.00)`.
3. Force-kills and deletes the container (`docker rm -f postgres-production-db`).
4. Re-launches a fresh container on the same named volume.
5. Verifies the survivor record is 100% intact!

### Step 3: Run the Volume Backup Utility
```bash
./scripts/backup-volume.sh
```
Generates two snapshots in `./backups/`:
1. `enterprise_db_backup_<timestamp>.sql` (Logical dump via `pg_dump`).
2. `volume_postgres_data_project2_<timestamp>.tar.gz` (Raw volume archive via Alpine sidecar).

### Step 4: Run the Disaster Recovery Restoration
```bash
./scripts/restore-volume.sh
```
1. Simulates complete volume destruction (`docker compose down -v`).
2. Creates a clean named volume.
3. Unpacks the latest `.tar.gz` archive into the volume.
4. Starts the database and verifies all records are restored.

---

## 6. Senior DevOps Interview Questions & Production Scenarios

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
