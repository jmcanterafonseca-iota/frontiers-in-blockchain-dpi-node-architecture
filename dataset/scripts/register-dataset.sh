#!/usr/bin/env bash
# =============================================================================
# register-dataset.sh — Provider provisioning for the DPI dataspace demo.
#
# Seeds, on the PROVIDER node (dpi_node_provider, host port 3010):
#   1. An ODRL "Offer" in the Policy Administration Point (pass-through negotiator).
#   2. A dataset published into the federated catalogue, mapped to the
#      dataspace-example-app (appId urn:app:dpi-frontiers). The distribution's
#      dcat:accessService.dcat:endpointURL is the provider's docker-network
#      address so the CONSUMER container can reach it after catalogue discovery.
#
# Post-#203 (organization identifiers):
#   - Login is email+password only (no x-api-key on a single-org node).
#   - Non-login routes are tenant-routed by ?organization=<org-did>. On a
#     single-org node the SingleTenantProcessor auto-injects the node org, so the
#     param is optional, but we pass it explicitly (read from engine-state.json).
#   - The catalogue bakes ?organization=<org-did> into the distribution
#     endpointURL at publish time (bakeOrganizationIntoDistributions).
#
# Run from the host with the stack up: ./dataset/scripts/register-dataset.sh
# =============================================================================
set -euo pipefail

PROVIDER_HOST="${PROVIDER_HOST:-http://localhost:3010}"
PROVIDER_CONTAINER="${PROVIDER_CONTAINER:-dpi_node_provider}"
PROVIDER_EMAIL="${PROVIDER_EMAIL:-admin-provider@node}"
PROVIDER_PASSWORD="${PROVIDER_PASSWORD:-1234-A-1234-b-1234}"

# Address the provider node advertises to consumers (docker-network name, NOT
# localhost/host.docker.internal). Trailing slash matters: the consumer-client
# does `new URL(endpointURL).pathname += "rights-management"`.
PROVIDER_NET_ENDPOINT="${PROVIDER_NET_ENDPOINT:-http://dpi_node_provider:3000/}"

APP_ID="urn:app:dpi-frontiers"
DATASET_ID="https://twin.example.org/dpi-consignment"
DATASET_TYPE="https://vocabulary.uncefact.org/Consignment"
OFFER_ID="urn:policy:dpi-consignment-offer"
DSP_CONTEXT="https://w3id.org/dspace/2025/1/context.jsonld"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { echo -e "${BLUE}  -> $1${NC}"; }
ok()   { echo -e "${GREEN}  [OK] $1${NC}"; }
fail() { echo -e "${RED}  [FAIL] $1${NC}"; exit 1; }

enc() { jq -rn --arg v "$1" '$v|@uri'; }

# --- 1. Login (token returned in the Set-Cookie access_token header) ----------
step "Login ${PROVIDER_EMAIL} @ ${PROVIDER_HOST}"
SESS=$(curl -sS -i -X POST "${PROVIDER_HOST}/authentication/login" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg e "$PROVIDER_EMAIL" --arg p "$PROVIDER_PASSWORD" '{email:$e,password:$p}')" \
    | grep -i '^set-cookie:' | grep -oE 'access_token=[^;]+' | head -1 | cut -d= -f2-)
[ -n "$SESS" ] || fail "login did not return an access_token"
ok "session token acquired"

# --- 2. Resolve the provider org DID from engine state ------------------------
step "Read provider org DID from ${PROVIDER_CONTAINER}:/var/lib/twin/engine-state.json"
ORG_DID=$(docker exec "${PROVIDER_CONTAINER}" sh -c 'cat /var/lib/twin/engine-state.json' 2>/dev/null \
    | jq -r '.nodeOrganizationId // empty')
[ -n "$ORG_DID" ] || fail "could not read nodeOrganizationId"
ORG_ENC=$(enc "$ORG_DID")
ok "provider org: ${ORG_DID}"

# --- 2b. Remove any prior offer/dataset so a re-run replaces them -------------
# The POSTs below are 409-on-exists (they do not update), so delete first.
step "Remove any prior offer/dataset (idempotent re-provision)"
curl -sS -o /dev/null -X DELETE \
    "${PROVIDER_HOST}/dataspace/app-datasets/$(enc "$DATASET_ID")?organization=${ORG_ENC}" \
    -H "Authorization: Bearer ${SESS}" || true
curl -sS -o /dev/null -X DELETE \
    "${PROVIDER_HOST}/rights-management/policy/admin/$(enc "$OFFER_ID")?organization=${ORG_ENC}" \
    -H "Authorization: Bearer ${SESS}" || true

# --- 3. Seed ODRL offer in the PAP -------------------------------------------
# The permission rule target MUST be a twin:jsonPath expression: the DefaultPolicyArbiter
# (data-plane PDP) rejects a plain dataset-id target with ruleTargetNotSupported. "$" selects
# the whole record. action "read" is the pull action.
step "Seed ODRL offer ${OFFER_ID}"
OFFER_BODY=$(jq -n --arg uid "$OFFER_ID" --arg assigner "$ORG_DID" --arg target "$DATASET_ID" \
    '{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Offer","@id":$uid,assigner:$assigner,target:$target,action:"read",permission:[{action:"read",target:{"@type":"twin:jsonPath","twin:jsonPathExpression":"$"}}]}')
OFFER_CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
    "${PROVIDER_HOST}/rights-management/policy/admin?organization=${ORG_ENC}" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer ${SESS}" -d "$OFFER_BODY")
{ [ "$OFFER_CODE" = 201 ] || [ "$OFFER_CODE" = 204 ] || [ "$OFFER_CODE" = 409 ]; } \
    || fail "offer seed failed (HTTP ${OFFER_CODE})"
ok "offer seeded (HTTP ${OFFER_CODE})"

# --- 4. Publish the dataset into the federated catalogue ----------------------
# dcat object form: the distribution carries the provider's reachable endpointURL,
# onto which the catalogue bakes ?organization=<org-did> at publish time.
step "Register dataset ${DATASET_ID} (endpoint ${PROVIDER_NET_ENDPOINT})"
DATASET_BODY=$(jq -n \
    --arg app "$APP_ID" --arg ds "$DATASET_ID" --arg dt "$DATASET_TYPE" \
    --arg pd "$ORG_DID" --arg ep "$PROVIDER_NET_ENDPOINT" --arg of "$OFFER_ID" \
    '{appId:$app,dataset:{
        "@context":{dcat:"http://www.w3.org/ns/dcat#",dcterms:"http://purl.org/dc/terms/",odrl:"http://www.w3.org/ns/odrl/2/"},
        "@type":"dcat:Dataset","@id":$ds,
        "dcterms:title":"DPI Consignment Dataset","dcterms:type":$dt,"dcterms:publisher":$pd,
        "dcat:distribution":{"@type":"dcat:Distribution","dcterms:format":"application/json",
            "dcat:accessService":{"@id":($ep+"rights-management"),"@type":"dcat:DataService","dcat:endpointURL":$ep}},
        "odrl:hasPolicy":{"@context":"http://www.w3.org/ns/odrl.jsonld","@type":"Offer","@id":$of,assigner:$pd,target:$ds,action:"read",permission:[{action:"read",target:{"@type":"twin:jsonPath","twin:jsonPathExpression":"$"}}]}
    }}')
# The PROVIDER node mounts its dataspace control plane at /dataspace (the
# /dataspace-control-plane base path only exists on the consumer, where the
# consumer-client extension overrides restPath).
DATASET_CODE=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
    "${PROVIDER_HOST}/dataspace/app-datasets?organization=${ORG_ENC}" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer ${SESS}" -d "$DATASET_BODY")
{ [ "$DATASET_CODE" = 201 ] || [ "$DATASET_CODE" = 204 ] || [ "$DATASET_CODE" = 409 ]; } \
    || fail "dataset registration failed (HTTP ${DATASET_CODE})"
ok "dataset registered (HTTP ${DATASET_CODE})"

echo ""
ok "Provider provisioned. Next: ./dataset/scripts/run-flow.sh (or trigger the consumer)."
