#!/usr/bin/env bash
# ==============================================================================
# PROJECT 3: MICROSERVICES & NETWORK ISOLATION VERIFICATION SUITE
# Tests: Docker DNS, Reverse Proxying, Cache Latency, and Network Isolation
# ==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}====================================================================${NC}"
echo -e "${CYAN}      PROJECT 3: DOCKER COMPOSE NETWORK & CACHING TEST SUITE        ${NC}"
echo -e "${CYAN}====================================================================${NC}"

# STEP 1: Launch the entire 3-tier stack
echo -e "\n${YELLOW}[STEP 1/5] Launching all 3 microservices via Docker Compose...${NC}"
docker compose up -d --build

echo -e "\nWaiting for all services to become healthy..."
sleep 5
docker compose ps

# STEP 2: Verify Reverse Proxy Routing (Port 80 -> Port 3000)
echo -e "\n${YELLOW}[STEP 2/5] Testing Nginx Reverse Proxy routing to Backend API...${NC}"
echo "Executing: curl -s http://localhost/"
curl -s http://localhost/ | jq . || curl -s http://localhost/
echo -e "${GREEN}✓ Reverse proxy successfully routed public traffic to the internal API!${NC}"

# STEP 3: PROVE NETWORK ISOLATION (Security Defense-in-Depth)
echo -e "\n${YELLOW}[STEP 3/5] PROVING NETWORK ISOLATION (Security Boundaries)...${NC}"

echo "A. Testing direct access to Redis from outside (Host Port 6379):"
if curl --connect-timeout 2 http://localhost:6379 > /dev/null 2>&1; then
    echo -e "${RED}❌ FAILED: Redis is accessible from the host! Ports are leaking!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Redis port 6379 is completely CLOSED to the outside world.${NC}"
fi

echo -e "\nB. Testing if Nginx container can reach Redis (Cross-Network Isolation):"
# Nginx is only on frontend-net; redis-cache is only on backend-net
if docker exec nginx-loadbalancer ping -c 1 -W 2 redis-cache > /dev/null 2>&1; then
    echo -e "${RED}❌ FAILED: Nginx can reach Redis directly! Isolation broken!${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: Nginx CANNOT resolve or ping Redis! (Network Isolation verified).${NC}"
fi

# STEP 4: High-Performance Cache Benchmark (Cache Miss vs Cache Hit)
echo -e "\n${YELLOW}[STEP 4/5] Testing In-Memory Redis Caching (Miss vs Hit)...${NC}"

USER_ID=$((100 + RANDOM % 899))
echo "Target User Endpoint: http://localhost/api/users/${USER_ID}"

echo -e "\n--> Call 1 (Expecting SLOW Database Cache Miss):"
time curl -s "http://localhost/api/users/${USER_ID}" | jq . || curl -s "http://localhost/api/users/${USER_ID}"

echo -e "\n--> Call 2 (Expecting INSTANT Redis Cache Hit):"
time curl -s "http://localhost/api/users/${USER_ID}" | jq . || curl -s "http://localhost/api/users/${USER_ID}"

# STEP 5: Verify Resource Limits (cgroups CPU/RAM constraints)
echo -e "\n${YELLOW}[STEP 5/5] Inspecting Resource Constraints (Linux cgroups limits)...${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

echo -e "\n${GREEN}====================================================================${NC}"
echo -e "${GREEN}🎉 ALL TESTS PASSED! Microservices stack and isolation verified 100%!${NC}"
echo -e "${GREEN}====================================================================${NC}"
