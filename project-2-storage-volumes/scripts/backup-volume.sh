#!/usr/bin/env bash
# ==============================================================================
# PROJECT 2: DOCKER PERSISTENT STORAGE & VOLUME LAB
# File: scripts/backup-volume.sh
# Purpose: Creates automated snapshots (Logical SQL Dump & Raw Volume Tarball)
# Pattern: Ephemeral Sidecar Container Backup Pattern
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$(pwd)/backups"
VOLUME_NAME="postgres_data_project2"
CONTAINER_NAME="postgres-production-db"

mkdir -p "${BACKUP_DIR}"

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}         PROJECT 2: AUTOMATED DOCKER VOLUME BACKUP UTILITY          ${NC}"
echo -e "${CYAN}====================================================================${NC}"

# ------------------------------------------------------------------------------
# BACKUP METHOD 1: Logical SQL Dump (via pg_dump inside running database)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[METHOD 1] Creating Logical SQL Dump using 'pg_dump'...${NC}"
SQL_BACKUP_FILE="${BACKUP_DIR}/enterprise_db_backup_${TIMESTAMP}.sql"

docker exec -i "${CONTAINER_NAME}" pg_dump -U devops_admin -d enterprise_db > "${SQL_BACKUP_FILE}"

echo -e "${GREEN}✓ Logical SQL backup created successfully!${NC}"
echo "  File: ${SQL_BACKUP_FILE}"
echo "  Size: $(du -h "${SQL_BACKUP_FILE}" | cut -f1)"

# ------------------------------------------------------------------------------
# BACKUP METHOD 2: Physical Raw Volume Tarball (via Ephemeral Alpine Container)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[METHOD 2] Creating Raw Volume Tarball using Ephemeral Alpine Container...${NC}"
TAR_BACKUP_FILE="volume_${VOLUME_NAME}_${TIMESTAMP}.tar.gz"

# Spins up a disposable Alpine container that mounts the named volume (read-only)
# and compresses the entire filesystem into our host ./backups directory
docker run --rm \
    --name volume-backup-worker \
    -v "${VOLUME_NAME}:/volume-data:ro" \
    -v "${BACKUP_DIR}:/backup-destination" \
    alpine:latest \
    tar -czf "/backup-destination/${TAR_BACKUP_FILE}" -C /volume-data .

echo -e "${GREEN}✓ Raw volume tarball created successfully!${NC}"
echo "  File: ${BACKUP_DIR}/${TAR_BACKUP_FILE}"
echo "  Size: $(du -h "${BACKUP_DIR}/${TAR_BACKUP_FILE}" | cut -f1)"

echo -e "\n${CYAN}====================================================================${NC}"
echo -e "${CYAN}Summary of Available Backups in ./backups:${NC}"
ls -lh "${BACKUP_DIR}"
echo -e "${CYAN}====================================================================${NC}"
