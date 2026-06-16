#!/usr/bin/env bash
# =============================================================================
# run-flow.sh — End-to-end 2-node dataspace flow for the DPI demo.
#
#   Provider (dpi_node_provider :3010): seed ODRL offer + publish dataset.
#   Consumer (dpi_node_consumer :3020): discover -> negotiate -> transfer -> pull.
#
# NEGOTIATION is driven by the consumer-client extension (POST /consumer-client/
# negotiate), which discovers the dataset in the provider's catalogue and runs the
# full DSP contract negotiation to FINALIZED in-process.
#
# TRANSFER + PULL are driven directly against the DSP transfer endpoints. The
# consumer-client's GET /consumer-client/query-data path cannot be used for the
# pull on this platform version: a PULL transfer has no automatic provider-side
# start, and the provider's startTransfer returns the dataAddress in its HTTP
# response without dispatching a TransferStartMessage to the consumer callback, so
# the consumer-client's onStarted callback never fires. We therefore drive the
# transfer the way the platform supports it (the same shape as tutorial 102):
#   consumer -> provider  POST /dataspace/transfers/request   (consumer trust)
#   provider              POST /dataspace/transfers/:pid/start (provider trust) -> dataAddress
#   consumer              GET  <dataAddress.endpoint>          (provider-issued token)
#
# Prereqs: stack up on the next.56 image, both nodes bootstrapped.
# Run from repo root: ./dataset/scripts/run-flow.sh
# (CONSUMER_HOST defaults to :3020; override if the consumer is published elsewhere.)
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PROVIDER_HOST="${PROVIDER_HOST:-http://localhost:3010}"
PROVIDER_CONTAINER="${PROVIDER_CONTAINER:-dpi_node_provider}"
PROVIDER_EMAIL="${PROVIDER_EMAIL:-admin-provider@node}"
CONSUMER_HOST="${CONSUMER_HOST:-http://localhost:3020}"
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

# --- 3. Transfer request (consumer -> provider) ------------------------------
echo ""; echo -e "${BOLD}Step 3: Request transfer (consumer -> provider)${NC}"
CORG=$(org_did "$CONSUMER_CONTAINER"); PORG=$(org_did "$PROVIDER_CONTAINER")
CTRUST=$(trust_jwt "$CONSUMER_HOST" "$CSESS" "$CORG"); [ -n "$CTRUST" ] || fail "consumer trust failed"
CPID="urn:uuid:$(uuid)"
TREQ=$(curl -sS -X POST "${PROVIDER_HOST}/dataspace/transfers/request?organization=$(enc "$PORG")" \
	-H 'Content-Type: application/json' -H "Authorization: Bearer ${CTRUST}" \
	-d "$(jq -n --arg ctx "$DSP_CTX" --arg ag "$AGID" --arg cp "$CPID" \
		--arg cb "http://${CONSUMER_CONTAINER}:3000/dataspace-control-plane?organization=$(enc "$CORG")" \
		'{"@context":[$ctx],"@type":"TransferRequestMessage",agreementId:$ag,consumerPid:$cp,callbackAddress:$cb,format:"HttpData-PULL"}')")
PROVPID=$(echo "$TREQ" | jq -r '.providerPid // empty')
[ -n "$PROVPID" ] || fail "transfer request returned no providerPid: $(echo "$TREQ" | head -c 300)"
ok "transfer REQUESTED, providerPid: ${PROVPID}"

# --- 4. Provider starts the transfer (PULL: returns dataAddress) -------------
echo ""; echo -e "${BOLD}Step 4: Provider starts transfer${NC}"
PSESS=$(login "$PROVIDER_HOST" "$PROVIDER_EMAIL"); [ -n "$PSESS" ] || fail "provider login failed"
PTRUST=$(trust_jwt "$PROVIDER_HOST" "$PSESS" "$PORG"); [ -n "$PTRUST" ] || fail "provider trust failed"
START=$(curl -sS -X POST "${PROVIDER_HOST}/dataspace/transfers/$(enc "$PROVPID")/start?organization=$(enc "$PORG")" \
	-H 'Content-Type: application/json' -H "Authorization: Bearer ${PTRUST}" \
	-d "$(jq -n --arg ctx "$DSP_CTX" --arg cp "$CPID" --arg pp "$PROVPID" \
		'{"@context":[$ctx],"@type":"TransferStartMessage",consumerPid:$cp,providerPid:$pp}')")
EP=$(echo "$START" | jq -r '.dataAddress.endpoint // empty')
TOK=$(echo "$START" | jq -r '(.dataAddress.endpointProperties//[])[]|select(.name=="authorization")|.value' | head -1)
[ -n "$EP" ] || fail "start returned no dataAddress endpoint: $(echo "$START" | head -c 300)"
ok "transfer STARTED, data endpoint: ${EP}"

# --- 5. Consumer pulls the data ----------------------------------------------
echo ""; echo -e "${BOLD}Step 5: Consumer pulls data${NC}"
# Pull from inside the consumer container so the provider container name resolves.
PULL=$(docker exec "$CONSUMER_CONTAINER" sh -c \
	"curl -sS -w '\n%{http_code}' -G '${EP}' --data-urlencode 'consumerPid=${CPID}' --data-urlencode 'type=${DATASET_TYPE}' -H 'Authorization: Bearer ${TOK}'")
CODE=$(echo "$PULL" | tail -1); BODY=$(echo "$PULL" | sed '$d')
COUNT=$(echo "$BODY" | jq '[.. | objects | select(.type=="Consignment" or .["@type"]=="Consignment")] | length' 2>/dev/null)
echo "  HTTP ${CODE}; body (first 600 chars): $(echo "$BODY" | head -c 600)"
{ [ "$CODE" = 200 ] && [ -n "$COUNT" ] && [ "$COUNT" -ge 1 ]; } 2>/dev/null \
	|| fail "pull did not return consignments (HTTP ${CODE})"
ok "pulled ${COUNT} consignment(s)"

echo ""
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "${BOLD}${GREEN}  SUCCESS — 2-node negotiate -> transfer -> retrieve verified${NC}"
echo -e "${BOLD}${GREEN}================================================================${NC}"
