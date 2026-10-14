# Project 3: Production Microservices Stack with Docker Compose

[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Nginx](https://img.shields.io/badge/Nginx-1.25_Alpine-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![Node.js](https://img.shields.io/badge/Node.js-18_Alpine-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Redis](https://img.shields.io/badge/Redis-7_Alpine-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![Network](https://img.shields.io/badge/Security-Multi--Tier_Isolated_Networks-brightgreen)](#)

A production-grade implementation of a **3-Tier Microservices Architecture** demonstrating **Nginx Reverse Proxying**, **Docker Embedded DNS Service Discovery**, **In-Memory Redis Caching**, and **Multi-Tier Defense-in-Depth Network Isolation**.

---

## 1. Executive Summary & Architecture Overview

In an enterprise microservices architecture, backend APIs and caching/database layers must **never be exposed directly to the public internet**. Exposing internal services leads to direct port scanning, distributed denial-of-service (DDoS) vulnerabilities, and unauthorized data extraction.

This project deploys **exactly 3 containers** across **2 completely isolated custom bridge networks**:

```
               PUBLIC INTERNET (Users / Browsers)
                               │
                               │ Port 80 (HTTP)
                               ▼
        +─────────────────────────────────────────────+
        │   TIER 1: NGINX REVERSE PROXY GATEWAY       │
        │   Container: nginx-loadbalancer             │
        │   Port: 80 (The ONLY exposed public port)   │
        +──────────────────────┬──────────────────────+
                               │
                FRONTEND-NET   │ (Docker DNS: "http://api-service:3000")
                               ▼
        +─────────────────────────────────────────────+
        │   TIER 2: NODE.JS REST MICROSERVICE         │
        │   Container: backend-microservice           │
        │   Internal Port: 3000 (No host port map)    │
        +──────────────────────┬──────────────────────+
                               │
                 BACKEND-NET   │ (Docker DNS: "redis-cache:6379")
                               ▼
        +─────────────────────────────────────────────+
        │   TIER 3: IN-MEMORY REDIS CACHE             │
        │   Container: redis-cache                    │
        │   Internal Port: 6379 (No host port map)    │
        +─────────────────────────────────────────────+
             (100% ISOLATED FROM THE INTERNET & NGINX)
```

### The 3 Containers in the Stack:
1. **`nginx-loadbalancer` (Tier 1 Gateway):**
   * Listens on host port `80`.
   * Intercepts incoming web traffic, handles timeouts, and proxies requests to `api-service:3000`.
   * Connected **only** to `frontend-net`.
2. **`backend-microservice` (Tier 2 Application):**
   * Node.js Express API built with our optimized multi-stage Alpine Dockerfile.
   * Connected to **both** `frontend-net` (to receive traffic from Nginx) and `backend-net` (to query Redis).
   * Has **no host ports exposed**.
3. **`redis-cache` (Tier 3 Data Cache):**
   * High-speed in-memory key-value store running on port `6379`.
   * Caches user requests with a 60-second TTL, dropping latency from **500 ms down to 1 ms**.
   * Connected **only** to `backend-net`. Completely invisible to Nginx and the outside world!

---

## 2. The 4 Core Architectural Principles

### 1. Defense-in-Depth Network Isolation
* Docker Compose creates two separate Linux bridge interfaces on the host: `microservice_frontend_net` and `microservice_backend_net`.
* **The Security Guarantee:** Even if an attacker finds a Remote Code Execution (RCE) bug in Nginx, they are physically trapped on `frontend-net`. They cannot scan, ping, or connect to Redis on `backend-net`.

### 2. Docker Embedded DNS (Service Discovery)
* No hardcoded IP addresses (like `172.18.0.3`) are used anywhere in our code or configurations.
* Docker runs an embedded DNS resolver at `127.0.0.11` inside every container.
* Nginx connects to `http://api-service:3000`, and the API connects to `redis-cache:6379`. Docker DNS handles routing dynamically, even if containers are destroyed and recreated with new IP addresses.

### 3. Sub-Millisecond Caching Engine
* **Cold Request (Cache Miss):** When User `#105` is requested for the first time, the API simulates an expensive 500 ms database fetch, writes the JSON into Redis, and returns the response.
* **Warm Request (Cache Hit):** Subsequent requests for User `#105` are served straight out of Redis RAM in **1 millisecond** (a **500x speedup**), protecting backend databases from being overwhelmed.

### 4. Container Resource Governance (Linux cgroups)
* Every container has strict CPU and Memory limits declared in `docker-compose.yml`:
  * Nginx: `0.5 CPU`, `128 MB RAM`
  * Backend API: `0.75 CPU`, `256 MB RAM`
  * Redis: `0.5 CPU`, `192 MB RAM`
* Prevents rogue memory leaks or traffic spikes in one container from exhausting host RAM and triggering an operating system kernel crash.

---

## 3. Repository Structure & Artifacts

```text
project-3-compose-stack/
├── docker-compose.yml         # Master orchestrator: 3 services, 2 networks, resource limits
├── nginx/
│   └── nginx.conf             # Reverse proxy config, upstream DNS pool, client IP headers
├── api/
│   ├── package.json           # Microservice dependencies (express, ioredis)
│   ├── Dockerfile             # Multi-stage production build (Alpine, non-root appuser)
│   └── src/
│       └── server.js          # REST API with Redis caching, /health probe & SIGTERM handler
├── scripts/
│   └── test-network.sh        # Automated validation suite (DNS, isolation, cache benchmark)
└── README.md                  # Comprehensive architectural documentation & interview prep
```

---

## 4. End-to-End Hands-On Testing Walkthrough

Follow these exact steps to launch, benchmark, and audit the entire microservices stack.

### Step 1: Launch the 3-Tier Stack
```bash
docker compose up -d --build
```
**Verification Check:**
Check that all 3 containers are up and reporting `(healthy)`:
```bash
docker compose ps
```
*Expected Output:*
```text
NAME                   IMAGE                         STATUS                    PORTS
backend-microservice   project-3-compose-stack-api   Up 15 seconds (healthy)   
nginx-loadbalancer     nginx:1.25-alpine             Up 10 seconds (healthy)   0.0.0.0:80->80/tcp
redis-cache            redis:7-alpine                Up 20 seconds (healthy)   
```
> Notice that **only Nginx** has a port mapping (`0.0.0.0:80->80/tcp`)! The API and Redis have empty port mappings on the host.

---

### Step 2: Test Reverse Proxy Routing (Port 80)
Send an HTTP request to Nginx:
```bash
curl -s http://localhost/ | jq .
```
*Expected Response:*
```json
{
  "message": "🚀 Microservices API Service Online",
  "service": "backend-api",
  "container": {
    "hostname": "8f3b2a1c4d5e",
    "platform": "linux",
    "uptimeSeconds": 25,
    "memoryUsageMB": "18.42"
  },
  "redisStatus": "CONNECTED"
}
```
* **What this proves:** You queried port 80 (Nginx), Nginx queried `api-service:3000` over `frontend-net`, the API checked Redis over `backend-net`, and returned the JSON payload!

---

### Step 3: Audit Network Isolation (Security Proof)

#### Test A: Is Redis accessible from the outside host?
```bash
curl --connect-timeout 2 http://localhost:6379
```
*Expected Result:*
```text
curl: (7) Failed to connect to localhost port 6379: Connection refused
```
✅ **PASSED:** Port 6379 is completely closed on the host. An external attacker cannot access or dump Redis keys.

#### Test B: Can Nginx talk directly to Redis?
```bash
docker exec nginx-loadbalancer ping -c 1 -W 2 redis-cache
```
*Expected Result:*
```text
ping: bad address 'redis-cache'
```
✅ **PASSED:** Nginx cannot resolve or reach Redis because they reside on different network bridges.

---

### Step 4: High-Performance Cache Benchmark (500x Speedup)

Query user `#200` twice in a row:

#### Call 1 (Cache Miss - Database Fetch):
```bash
time curl -s http://localhost/api/users/200 | jq .
```
*Output:*
```json
{
  "source": "DATABASE_CACHE_MISS 🐢",
  "latencyMs": "504ms (Slow DB Fetch, now cached for 60s)",
  "data": {
    "id": "200",
    "name": "Customer Account #200",
    "tier": "ENTERPRISE_GOLD"
  }
}
real    0m0.518s
```

#### Call 2 (Cache Hit - Instant In-Memory RAM):
```bash
time curl -s http://localhost/api/users/200 | jq .
```
*Output:*
```json
{
  "source": "REDIS_CACHE_HIT ⚡",
  "latencyMs": "1ms (Instant In-Memory)",
  "data": {
    "id": "200",
    "name": "Customer Account #200",
    "tier": "ENTERPRISE_GOLD"
  }
}
real    0m0.008s
```
⚡ **Performance Proof:** Latency dropped from **518 ms down to 8 ms**!

---

### Step 5: Validate Resource Limits (cgroups)
Inspect live CPU and memory consumption:
```bash
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```
*Expected Output:*
```text
NAME                   CPU %     MEM USAGE / LIMIT     MEM %
backend-microservice   0.08%     32.4MiB / 256MiB      12.65%
nginx-loadbalancer     0.02%     14.1MiB / 128MiB      11.01%
redis-cache            0.15%     9.8MiB / 192MiB       5.10%
```

---

### Step 6: Run the All-in-One Automated Test Script
Execute our automated test harness:
```bash
chmod +x scripts/*.sh
./scripts/test-network.sh
```

---

## 5. Production Scenarios & Real-World War Stories

### Scenario A: The "Thundering Herd" & Cache Stampede
* **The Problem:** In a massive sale event (like Black Friday), millions of users hit the same product page at the exact second its cache expires. If 50,000 requests hit a cache miss at the same millisecond, all 50,000 queries hit the database at once, crashing the database cluster.
* **Our Solution:** In `server.js`, we set an explicit TTL (`'EX', 60`) and connection timeouts. In production, Redis mutex locking (or probabilistic early expiration) is used so only ONE worker queries the database while other requests wait for the cache to re-warm.

### Scenario B: Zero-Downtime Rolling Restarts with `condition: service_healthy`
* **The Problem:** Standard Docker `depends_on` only checks if the Redis container process has spawned. If your API starts sending queries before Redis has finished reading its snapshot file into memory, all initial user requests fail with `500 Internal Server Error`.
* **Our Solution:** We use `condition: service_healthy` with `redis-cli ping`. Nginx will not open port 80 until the API reports healthy, and the API will not boot until Redis confirms it is ready to accept commands.

### Scenario C: Preventing Server Death with Redis `allkeys-lru`
* **The Problem:** A developer forgets to set TTLs, and Redis memory grows continuously until the Linux kernel Out-Of-Memory (OOM) Killer abruptly murders the process.
* **Our Solution:** In `docker-compose.yml`, we passed `--maxmemory 128mb --maxmemory-policy allkeys-lru`. When memory reaches 128 MB, Redis automatically evicts the least recently used keys, remaining stable and fast forever.

---

## 6. Senior DevOps Interview Questions & Production Defense

### Q1: How does Docker Embedded DNS work internally when a container queries `api-service`?
> **Answer:**
> Docker embeds a lightweight DNS server at `127.0.0.11` inside every user-defined bridge network. When a container makes a DNS request for `api-service`, the Linux kernel forwards the UDP packet on port 53 to the embedded DNS daemon. Docker looks up its internal container registry, resolves `api-service` to its current internal IP (e.g. `172.20.0.3`), and returns the response. If the query is for an external domain (e.g., `google.com`), Docker automatically forwards it to the host machine's upstream DNS resolvers (`/etc/resolv.conf`).

### Q2: What is the security advantage of using multi-tier Docker bridge networks over a single default bridge?
> **Answer:**
> Using a single default bridge allows every container to talk to every other container on the host by default. If an attacker compromises an edge web server (like Nginx), they can immediately port-scan and attack the database or cache. With **multi-tier isolated bridges** (`frontend-net` vs `backend-net`), containers on different networks have no routing path between them. Nginx cannot resolve or route packets to Redis, enforcing the principle of least privilege at the network layer.

### Q3: Why is `depends_on` alone not enough for reliable service startup in Docker Compose?
> **Answer:**
> In Docker Compose v2, `depends_on` without conditions only controls **startup order**, not **readiness**. It starts Container B as soon as Container A has created its PID, even if Container A takes 15 seconds to initialize its database engine. If Container B tries to connect immediately, it crashes with a connection refused error. Using `condition: service_healthy` forces Docker Compose to poll Container A's healthcheck command until it returns exit code 0 before starting Container B.

### Q4: What happens if a container exceeds its memory limit (`deploy.resources.limits.memory`)?
> **Answer:**
> In Linux, container resource limits are enforced by **cgroups (Control Groups)**. If a container exceeds its defined memory limit, the Linux kernel triggers the **OOM (Out-Of-Memory) Killer**. The kernel selects the process with the highest `oom_score` inside that cgroup and terminates it with `SIGKILL` (Exit Code `137`). To handle this in production, containers should set both memory limits and reservation thresholds, while applications should configure internal memory pools (like Node's `--max-old-space-size` or Redis's `maxmemory`) to prevent hitting the kernel cgroup limit.

### Q5: What is the difference between Docker's Default Bridge and a User-Defined Bridge network?
> **Answer:**
> 1. **DNS Resolution:** User-defined bridges provide automatic DNS resolution between containers by container name. The default bridge does not; containers must be linked using legacy `--link` or connect via raw IP addresses.
> 2. **Isolation:** Containers on the default bridge share a flat network where any container can communicate with any other container. User-defined bridges isolate application stacks from each other.
> 3. **Live Reconfiguration:** Containers can be attached and detached from user-defined bridge networks on the fly without stopping the container.
