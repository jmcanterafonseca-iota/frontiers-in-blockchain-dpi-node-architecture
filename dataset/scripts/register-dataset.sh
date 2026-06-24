#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") [email password]" >&2
    echo "" >&2
    echo "  email      Login email (default: from provider-authn.json)" >&2
    echo "  password   Login password (default: from provider-authn.json)" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$#" -ne 0 ] && [ "$#" -ne 2 ]; then
    usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTHN_FILE="$SCRIPT_DIR/../participants/provider-authn.json"

if [ "$#" -eq 2 ]; then
    EMAIL="$1"
    PASSWORD="$2"
else
    if [ ! -f "$AUTHN_FILE" ]; then
        echo "Error: credentials file not found: $AUTHN_FILE" >&2
        exit 1
    fi
    EMAIL=$(jq -r '.email' "$AUTHN_FILE")
    PASSWORD=$(jq -r '.password' "$AUTHN_FILE")
fi

BASE_URL="${BASE_URL:-http://localhost:3010}"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

echo -e "${DIM}Authenticating as ${RESET}${YELLOW}$EMAIL${RESET}${DIM}...${RESET}"
cookie=$(curl --silent "$BASE_URL/authentication/login" \
    --header 'Content-Type: application/json' \
    --data-raw "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" \
    --dump-header - \
    --output /dev/null \
    | grep -i '^set-cookie:' | sed 's/^[Ss]et-[Cc]ookie: //;s/;.*//')

if [ -z "$cookie" ]; then
    echo -e "${RED}Authentication failed${RESET}" >&2
    exit 1
fi
echo -e "${DIM}Authenticated.${RESET}"
echo ""

# Resolve the provider's node identity, used as the offer assigner / dataset publisher. This must
# match the identity the provider can actually sign as: the offer assigner becomes the transfer's
# providerIdentity, and the provider can only mint the TransferStartMessage trust VC for an identity
# whose key is in its own vault. Read it from the provider participant file.
PROVIDER_FILE="$SCRIPT_DIR/../participants/provider.json"
if [ ! -f "$PROVIDER_FILE" ]; then
    echo -e "${RED}Provider file not found: ${PROVIDER_FILE}${RESET}" >&2
    exit 1
fi
PROVIDER_DID=$(jq -r '.id // empty' "$PROVIDER_FILE")
if [ -z "$PROVIDER_DID" ]; then
    echo -e "${RED}Could not resolve provider identity (.id) from ${PROVIDER_FILE}.${RESET}" >&2
    exit 1
fi
echo -e "${DIM}Provider identity: ${RESET}${YELLOW}${PROVIDER_DID}${RESET}"
echo ""

# Load the offer/policy from the participant file instead of inlining it here. Override the
# assigner with the resolved provider identity so the policy is signable by the provider node.
OFFER_FILE="$SCRIPT_DIR/../participants/provider-offer.json"
if [ ! -f "$OFFER_FILE" ]; then
    echo -e "${RED}Offer file not found: ${OFFER_FILE}${RESET}" >&2
    exit 1
fi

OFFER_JSON=$(jq -c --arg assigner "$PROVIDER_DID" '.assigner = $assigner' "$OFFER_FILE")
POLICY_ID=$(printf '%s' "$OFFER_JSON" | jq -r '.["@id"] // .uid // empty')
if [ -z "$POLICY_ID" ]; then
    echo -e "${RED}Could not determine policy id (@id/uid) from ${OFFER_FILE}.${RESET}" >&2
    exit 1
fi

encoded_policy_id="${POLICY_ID//:/%3A}"
encoded_policy_id="${encoded_policy_id//\//%2F}"

# Detect whether the policy already exists; if so, delete it so it can be re-created cleanly.
echo -e "${DIM}Checking whether policy ${RESET}${YELLOW}${POLICY_ID}${RESET}${DIM} exists...${RESET}"
existing_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    "$BASE_URL/rights-management/policy/admin/$encoded_policy_id" \
    --header "Cookie: $cookie")

policy_existed=false
if [ "$existing_code" -eq 200 ]; then
    policy_existed=true
    echo -e "${YELLOW}Policy already exists — deleting it before re-creating.${RESET}"
    delete_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --request DELETE \
        "$BASE_URL/rights-management/policy/admin/$encoded_policy_id" \
        --header "Cookie: $cookie")
    if [ "$delete_code" -ne 200 ] && [ "$delete_code" -ne 204 ]; then
        echo -e "${RED}Error: failed to delete existing policy (HTTP $delete_code)${RESET}" >&2
        exit 1
    fi
    echo -e "${DIM}Existing policy deleted.${RESET}"
elif [ "$existing_code" -eq 404 ]; then
    echo -e "${DIM}Policy does not exist yet — it will be created.${RESET}"
else
    echo -e "${RED}Error: unexpected response while checking policy (HTTP $existing_code)${RESET}" >&2
    exit 1
fi

echo -e "${DIM}Creating policy...${RESET}"
response=$(curl --silent "$BASE_URL/rights-management/policy/admin" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data-raw "$OFFER_JSON")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: failed to create policy (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

if [ "$policy_existed" = true ]; then
    echo -e "${BOLD}${GREEN}Policy deleted and re-created successfully.${RESET}"
else
    echo -e "${BOLD}${GREEN}Policy created successfully.${RESET}"
fi
echo ""

DATASET_ID="https://frontiers.example.org/dataset-1"
encoded_dataset_id="${DATASET_ID//:/%3A}"
encoded_dataset_id="${encoded_dataset_id//\//%2F}"

# Detect whether the app-dataset association already exists; if so, delete it so the dataset can be
# republished with the current policy/definition (a plain create would otherwise fail with 409).
echo -e "${DIM}Checking whether dataset ${RESET}${YELLOW}${DATASET_ID}${RESET}${DIM} is already registered...${RESET}"
existing_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    "$BASE_URL/dataspace/app-datasets/$encoded_dataset_id" \
    --header "Cookie: $cookie")

dataset_existed=false
if [ "$existing_code" -eq 200 ]; then
    dataset_existed=true
    echo -e "${YELLOW}Dataset already registered — deleting the app-dataset association before republishing.${RESET}"
    delete_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --request DELETE \
        "$BASE_URL/dataspace/app-datasets/$encoded_dataset_id" \
        --header "Cookie: $cookie")
    if [ "$delete_code" -ne 200 ] && [ "$delete_code" -ne 204 ]; then
        echo -e "${RED}Error: failed to delete existing app-dataset (HTTP $delete_code)${RESET}" >&2
        exit 1
    fi
    echo -e "${DIM}Existing app-dataset deleted.${RESET}"
elif [ "$existing_code" -eq 404 ]; then
    echo -e "${DIM}Dataset not registered yet — it will be created.${RESET}"
else
    echo -e "${RED}Error: unexpected response while checking dataset (HTTP $existing_code)${RESET}" >&2
    exit 1
fi

echo -e "${DIM}Registering dataset...${RESET}"

# Reuse the very same ODRL offer (loaded from provider-offer.json, assigner overridden) as the
# dataset's hasPolicy, so the published dataset advertises exactly the policy that was created.
# Its @context is dropped because the parent dataset document already declares one.
DATASET_PAYLOAD=$(jq -n \
    --arg publisher "$PROVIDER_DID" \
    --arg datasetId "$DATASET_ID" \
    --argjson offer "$OFFER_JSON" '
{
    "appId": "urn:app:dpi-frontiers",
    "dataset": {
        "@context": [
            "https://w3id.org/dspace/2025/1/context.jsonld",
            { "dcterms": "http://purl.org/dc/terms/" }
        ],
        "@id": $datasetId,
        "@type": "Dataset",
        "dcterms:type": "https://vocabulary.uncefact.org/Consignment",
        "dcterms:publisher": $publisher,
        "hasPolicy": [ ($offer | del(.["@context"])) ],
        "distribution": {
            "@id": "https://twin.example.org/distribution-1",
            "@type": "Distribution",
            "accessService": {
                "@id": "urn:uuid:4aa2dcc8-4d2d-569e-d634-8394a8834d77",
                "@type": "DataService",
                "endpointURL": "http://dpi.provider:3000"
            },
            "format": "HttpData-PULL"
        }
    }
}')

response=$(curl --silent "$BASE_URL/dataspace/app-datasets" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data-raw "$DATASET_PAYLOAD")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: failed to register dataset (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

if [ "$dataset_existed" = true ]; then
    echo -e "${BOLD}${GREEN}Dataset deleted and republished successfully.${RESET}"
else
    echo -e "${BOLD}${GREEN}Dataset registered successfully.${RESET}"
fi
echo "$body" | jq . 2>/dev/null || echo "$body"
