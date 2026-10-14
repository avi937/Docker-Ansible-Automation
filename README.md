# 🐳 Docker & Ansible Infrastructure Automation Portfolio

[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Status](https://img.shields.io/badge/Portfolio_Status-In_Progress-brightgreen)](#)

A structured collection of production-grade containerization and configuration management architectures built with **Docker**, **Docker Compose**, and **Ansible**. Designed with enterprise security, minimal image footprints, multi-stage caching, idempotent server automation, and end-to-end cloud orchestration.

---

## 📂 Projects Directory

| # | Project | Technology | Description | Status |
| :---: | :--- | :---: | :--- | :---: |
| **01** | [**Project 1: Multi-Stage Dockerfile Optimization**](./project-1-multistage-docker/) | Docker, Alpine, Node/TS | Production multi-stage image engineering, layer caching, non-root security, shrinking image from 1.64GB to 187MB. | `Completed ✅` |
| **02** | [**Project 2: Storage & Volume Persistence**](./project-2-storage-volumes/) | Docker Volumes, PostgreSQL | Zero-data-loss database persistence, named volumes vs bind mounts, automated sidecar backups, and disaster recovery. | `Completed ✅` |
| **03** | [**Project 3: Production Microservices with Docker Compose**](./project-3-compose-stack/) | Compose, Nginx, Redis | Multi-tier network isolation, custom bridge DNS, environment injection, sub-millisecond caching, and cgroups resource limits. | `Completed ✅` |
| **04** | [**Project 4: Ansible Agentless Configuration & Playbooks**](./project-4-ansible-playbooks/) | Ansible, Linux, SSH | Idempotent system configuration, package management, user hardening, and service management across fleets. | `Planned ⏳` |
| **05** | [**Project 5: Enterprise Ansible Roles & Secret Vault**](./project-5-ansible-roles-vault/) | Ansible Roles, Jinja2, Vault | Reusable role architecture, dynamic template generation, and AES-256 encrypted secret management. | `Planned ⏳` |
| **06** | [**Project 6: Capstone Automated Cloud Web Cluster**](./project-6-capstone-cluster/) | Terraform + Ansible + Docker | Terraform spins up 3 bare VMs → Ansible hardens OS & installs Docker → Docker runs load-balanced microservices! | `Planned ⏳` |

---

## 🎯 Key Engineering Competencies

* **Minimal Image Engineering:** Multi-stage builds separating compilers from runtime artifacts, cutting image sizes by 88%+.
* **Container Security Hardening:** Enforcing non-root `USER`, read-only filesystems, `.dockerignore` hygiene, and multi-tier network boundaries.
* **Storage Persistence:** Architecting stateful data with Docker Named Volumes for zero data loss during container upgrades.
* **Microservices Orchestration:** Designing defense-in-depth networks, reverse proxy gateways, and high-performance in-memory caching.
* **Idempotent Automation:** Writing Ansible playbooks that guarantee repeatable desired state without configuration drift.
* **Full-Stack DevOps Marriage:** Unifying Terraform (IaC) + Ansible (Configuration) + Docker (Workloads) into an automated deployment pipeline.
