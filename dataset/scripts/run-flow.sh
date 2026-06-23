#!/usr/bin/env bash
# =============================================================================
# run-flow.sh — End-to-end 2-node dataspace flow for the DPI demo.
#
#   Provider (dpi_node_provider :3010): seed ODRL offer + publish dataset.
#   Consumer (dpi_node_consumer :3026): discover -> negotiate -> transfer -> pull.
#
# NEGOTIATION is driven by the consumer-client extension (POST /consumer-client/
# negotiate), which discovers the dataset in the provider's catalogue and runs the
# full DSP contract negotiation to FINALIZED in-process.
#
# TRANSFER + PULL are driven by the consumer-client extension (POST /consumer-client/
# query-data). The provider runs DPI_NODE_DATASPACE_AUTO_START_TRANSFERS=true (#224):
# query-data requests the transfer, the provider auto-starts and POSTs the
# TransferStartMessage to the consumer's control-plane callback, and the
# consumer-client's onStarted pulls the entities via the data-plane RestClient and
# returns them in the query-data response. One call covers request -> start -> pull.
#
# Note: the transfer channel (dataAddress.endpoint) is the data-plane BASE
# (DPI_NODE_DATASPACE_DATA_PLANE_PATH = "dataspace"); the entities resource lives at
# <base>/entities, which the data-plane RestClient appends itself.
#
# Prereqs: stack up on the next.64 image, both nodes bootstrapped.
# Run from repo root: ./dataset/scripts/run-flow.sh
# (CONSUMER_HOST defaults to :3026; override if the consumer is published elsewhere.)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PROVIDER_HOST="${PROVIDER_HOST:-http://localhost:3010}"
PROVIDER_CONTAINER="${PROVIDER_CONTAINER:-dpi_node_provider}"
PROVIDER_EMAIL="${PROVIDER_EMAIL:-admin-provider@node}"
CONSUMER_HOST="${CONSUMER_HOST:-http://localhost:3026}"
CONSUMER_CONTAINER="${CONSUMER_CONTAINER:-dpi_node_consumer}"
CONSUMER_EMAIL="${CONSUMER_EMAIL:-admin@node}"
PASSWORD="${PASSWORD:-1234-A-1234-b-1234}"
DATASET_TYPE="https://vocabulary.uncefact.org/Consignment"
DSP_CTX="https://w3id.org/dspace/2025/1/context.jsonld"
TRUST_VM="trust-assertion"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
step() { echo -e "${BLUE}  -> $1${NC}"; }
ok()   { echo -e "${GREEN}  [OK] $1${NC}"; }
fail() { echo -e "${RED}  [FAIL] $1${NC}"; exit 1; }
enc()  { jq -rn --arg v "$1" '$v|@uri'; }

login() { # host email
	curl -sS -i -X POST "$1/authentication/login" -H 'Content-Type: application/json' \
		-d "{\"email\":\"$2\",\"password\":\"${PASSWORD}\"}" \
		| grep -i '^set-cookie:' | grep -oE 'access_token=[^;]+' | head -1 | cut -d= -f2-
}
org_did() { docker exec "$1" sh -c 'cat /var/lib/twin/engine-state.json' | jq -r '.nodeOrganizationId'; }
trust_jwt() { # host sess org
	curl -sS -X POST "$1/identity/$3/verifiable-credential/${TRUST_VM}?organization=$(enc "$3")" \
		-H 'Content-Type: application/json' -H "Cookie: access_token=$2" \
		-d "{\"subject\":{\"id\":\"$3\"}}" | jq -r '.jwt // empty'
}
uuid() { docker exec "$CONSUMER_CONTAINER" sh -c 'cat /proc/sys/kernel/random/uuid'; }

# --- 1. Provider provisioning ------------------------------------------------
echo -e "${BOLD}Step 1: Provider provisioning (offer + dataset)${NC}"
bash "${SCRIPT_DIR}/register-dataset.sh" || fail "provider provisioning failed"

# --- 2. Consumer negotiate (consumer-client) ---------------------------------
echo ""; echo -e "${BOLD}Step 2: Negotiate (consumer-client drives discovery + negotiation)${NC}"
CSESS=$(login "$CONSUMER_HOST" "$CONSUMER_EMAIL"); [ -n "$CSESS" ] || fail "consumer login failed"
NEG=$(curl -sS --max-time 120 -X POST "${CONSUMER_HOST}/consumer-client/negotiate" \
	-H 'Content-Type: application/json' -H "Cookie: access_token=${CSESS}" -d '{}')
AGID=$(echo "$NEG" | jq -r '.agreementId // empty')
[ -n "$AGID" ] || fail "negotiate returned no agreementId: $(echo "$NEG" | head -c 300)"
ok "negotiation FINALIZED, agreement: ${AGID}"

# --- 3. Transfer + pull (consumer-client query-data; provider auto-start) -----
echo ""; echo -e "${BOLD}Step 3: Transfer + pull (consumer-client; provider auto-starts the transfer)${NC}"
# The provider runs DPI_NODE_DATASPACE_AUTO_START_TRANSFERS=true (#224), so the
# consumer-client's query-data drives the whole transfer in one call: it requests
# the transfer, the provider auto-starts and POSTs the TransferStartMessage to the
# consumer callback, and the consumer-client's onStarted pulls via the data-plane
# RestClient. (The old manual two-step start is incompatible with auto-start mode.)
QD=$(curl -sS --max-time 150 -w "\n%{http_code}" -X POST "${CONSUMER_HOST}/consumer-client/query-data" \
	-H 'Content-Type: application/json' -H "Cookie: access_token=${CSESS}" \
	-d "$(jq -n --arg ag "$AGID" --arg et "$DATASET_TYPE" '{agreementId:$ag,entityType:$et}')")
CODE=$(echo "$QD" | tail -1); BODY=$(echo "$QD" | sed '$d')
COUNT=$(echo "$BODY" | jq '[.. | objects | select(.type=="Consignment" or .["@type"]=="Consignment")] | length' 2>/dev/null)
echo "  HTTP ${CODE}; body (first 600 chars): $(echo "$BODY" | head -c 600)"
{ [ "$CODE" = 200 ] && [ -n "$COUNT" ] && [ "$COUNT" -ge 1 ]; } 2>/dev/null \
	|| fail "query-data did not return consignments (HTTP ${CODE})"
ok "pulled ${COUNT} consignment(s)"

echo ""
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "${BOLD}${GREEN}  SUCCESS — 2-node negotiate -> transfer -> retrieve verified${NC}"
echo -e "${BOLD}${GREEN}================================================================${NC}"
