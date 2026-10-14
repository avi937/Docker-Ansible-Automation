#!/usr/bin/env bash
# ==============================================================================
# PROJECT 2: DOCKER PERSISTENT STORAGE & VOLUME LAB
# File: scripts/restore-volume.sh
# Purpose: Simulates total volume deletion and restores data from a tar.gz backup
# Pattern: Ephemeral Sidecar Container Restore Pattern
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BACKUP_DIR="$(pwd)/backups"
VOLUME_NAME="postgres_data_project2"
CONTAINER_NAME="postgres-production-db"

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}     PROJECT 2: DISASTER RECOVERY & VOLUME RESTORATION UTILITY      ${NC}"
echo -e "${CYAN}====================================================================${NC}"

# STEP 1: Find the latest .tar.gz backup file
echo -e "\n${YELLOW}[STEP 1/5] Searching for latest volume backup in ./backups...${NC}"

if [ ! -d "${BACKUP_DIR}" ]; then
    echo -e "${RED}Error: Backup directory './backups' does not exist! Run backup-volume.sh first.${NC}"
    exit 1
fi

LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/volume_${VOLUME_NAME}_*.tar.gz 2>/dev/null | head -n 1 || true)

if [ -z "${LATEST_BACKUP}" ]; then
    echo -e "${RED}Error: No volume backup (*.tar.gz) found in './backups'!${NC}"
    echo "Please run './scripts/backup-volume.sh' first to generate a snapshot."
    exit 1
fi

echo -e "${GREEN}✓ Found latest backup file:${NC} ${LATEST_BACKUP}"

# STEP 2: SIMULATE WORST-CASE ACCIDENTAL DELETION (Destroy container AND volume)
echo -e "\n${RED}====================================================================${NC}"
echo -e "${RED}[STEP 2/5] SIMULATING TOTAL DISASTER: DELETING CONTAINER AND VOLUME! ${NC}"
echo -e "${RED}====================================================================${NC}"
echo "Stopping container..."
docker compose down -v || true

echo "Forcefully removing volume if still lingering..."
docker volume rm -f "${VOLUME_NAME}" > /dev/null 2>&1 || true

echo -e "${RED}✓ The database container AND the volume have been completely wiped!${NC}"
echo "Verifying volume is gone from Docker:"
docker volume ls | grep "${VOLUME_NAME}" || echo "  -> Volume '${VOLUME_NAME}' DOES NOT EXIST (Verified wiped)."

# STEP 3: Recreate an empty named volume
echo -e "\n${YELLOW}[STEP 3/5] Creating a fresh, blank named volume: '${VOLUME_NAME}'...${NC}"
docker volume create "${VOLUME_NAME}"
echo -e "${GREEN}✓ Blank volume created.${NC}"

# STEP 4: Restore data into the blank volume using a temporary Alpine container
echo -e "\n${YELLOW}[STEP 4/5] Restoring backup archive into the new volume via Alpine helper...${NC}"
BACKUP_FILENAME=$(basename "${LATEST_BACKUP}")

docker run --rm \
    --name volume-restore-worker \
    -v "${VOLUME_NAME}:/volume-destination" \
    -v "${BACKUP_DIR}:/backup-source:ro" \
    alpine:latest \
    tar -xzf "/backup-source/${BACKUP_FILENAME}" -C /volume-destination

echo -e "${GREEN}✓ Files uncompressed and restored into volume successfully!${NC}"

# STEP 5: Start the database container and verify restored data
echo -e "\n${YELLOW}[STEP 5/5] Launching database on the restored volume...${NC}"
docker compose up -d

echo "Waiting for PostgreSQL to accept connections..."
until docker exec "${CONTAINER_NAME}" pg_isready -U devops_admin -d enterprise_db > /dev/null 2>&1; do
    echo "  -> Waiting for database to boot..."
    sleep 2
done

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}                 VERIFYING RESTORED DATABASE RECORDS                ${NC}"
echo -e "${GREEN}====================================================================${NC}"
docker exec -i "${CONTAINER_NAME}" psql -U devops_admin -d enterprise_db -c "
SELECT account_id, customer_name, email, balance_usd, created_at FROM customer_accounts;
"

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}🎉 DISASTER RECOVERY SUCCESSFUL! ALL DATA RESTORED 100%!           ${NC}"
echo -e "${GREEN}====================================================================${NC}"
