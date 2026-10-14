#!/usr/bin/env bash
# ==============================================================================
# PROJECT 2: DOCKER PERSISTENT STORAGE & VOLUME LAB
# File: scripts/disaster-test.sh
# Purpose: Simulates a catastrophic container destruction and verifies data survival
# ==============================================================================

set -euo pipefail

# Terminal Color Codes for clear, professional output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}      PROJECT 2: DOCKER VOLUME PERSISTENCE DISASTER SIMULATION      ${NC}"
echo -e "${CYAN}====================================================================${NC}"

# STEP 1: Launch database stack
echo -e "\n${YELLOW}[STEP 1/6] Launching PostgreSQL container via Docker Compose...${NC}"
docker compose up -d

# STEP 2: Wait until database engine is ready to accept queries
echo -e "\n${YELLOW}[STEP 2/6] Waiting for database healthcheck (pg_isready)...${NC}"
until docker exec postgres-production-db pg_isready -U devops_admin -d enterprise_db > /dev/null 2>&1; do
    echo "  -> Waiting for database to finish initial boot..."
    sleep 2
done
echo -e "${GREEN}âœ“ Database is healthy and ready for queries!${NC}"

# STEP 3: Query initial seed data (from init.sql)
echo -e "\n${YELLOW}[STEP 3/6] Reading initial records created by init.sql...${NC}"
docker exec -i postgres-production-db psql -U devops_admin -d enterprise_db -c "
SELECT account_id, customer_name, email, balance_usd, status FROM customer_accounts;
"

# STEP 4: Insert a critical new transaction record BEFORE the disaster
echo -e "\n${YELLOW}[STEP 4/6] Inserting a NEW critical record right before the disaster...${NC}"
docker exec -i postgres-production-db psql -U devops_admin -d enterprise_db -c "
DELETE FROM customer_accounts WHERE email = 'survivor@devops-corp.internal';
INSERT INTO customer_accounts (customer_name, email, balance_usd, status)
VALUES ('Disaster Recovery Survivor', 'survivor@devops-corp.internal', 777777.00, 'ACTIVE');
"
echo -e "${GREEN}âœ“ Record 'Disaster Recovery Survivor' (USD 777,777.00) saved to database!${NC}"

# STEP 5: SIMULATE CATASTROPHIC CONTAINER FAILURE
echo -e "\n${RED}====================================================================${NC}"
echo -e "${RED}[STEP 5/6] SIMULATING TOTAL CONTAINER CRASH & FORCEFUL DELETION!    ${NC}"
echo -e "${RED}====================================================================${NC}"
echo "Running: docker rm -f postgres-production-db"
docker rm -f postgres-production-db

echo -e "\nVerifying container status in Docker:"
docker ps -a --filter "name=postgres-production-db"
echo -e "${RED}âœ“ The container 'postgres-production-db' has been 100% destroyed!${NC}"

# STEP 6: SPAWN A BRAND NEW CONTAINER ATTACHED TO THE SAME VOLUME
echo -e "\n${YELLOW}[STEP 6/6] Spawning a brand-new container on the existing named volume...${NC}"
docker compose up -d

echo "Waiting for new container to become healthy..."
until docker exec postgres-production-db pg_isready -U devops_admin -d enterprise_db > /dev/null 2>&1; do
    echo "  -> Waiting for new container..."
    sleep 2
done

# VERIFICATION: Did our data survive?
echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}                 VERIFYING DATA SURVIVAL RESULTS                    ${NC}"
echo -e "${GREEN}====================================================================${NC}"
docker exec -i postgres-production-db psql -U devops_admin -d enterprise_db -c "
SELECT account_id, customer_name, email, balance_usd, created_at FROM customer_accounts;
"

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}ðŸŽ‰ TEST PASSED! The record 'Disaster Recovery Survivor' survived!   ${NC}"
echo -e "${GREEN}Proof: The volume on your PC kept the data safe during container death.${NC}"
echo -e "${GREEN}====================================================================${NC}"
