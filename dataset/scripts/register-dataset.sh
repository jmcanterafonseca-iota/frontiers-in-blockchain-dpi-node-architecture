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

echo -e "${DIM}Creating policy...${RESET}"
response=$(curl --silent "$BASE_URL/rights-management/policy/admin" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data-raw '{
        "@context": "http://www.w3.org/ns/odrl.jsonld",
        "@type": "Offer",
        "@id": "urn:policy:test-policy-offer-1",
        "uid": "urn:policy:test-policy-offer-1",
        "target": "https://frontiers.example.org/dataset-1",
        "assigner": "'"$PROVIDER_DID"'",
        "permission": [
            {
                "action": "read",
                "target": {
                    "@type": "twin:jsonPath",
                    "twin:jsonPathExpression": "$"
                }
            }
        ]
    }')

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -eq 409 ]; then
    echo -e "${YELLOW}Warning: policy already exists, proceeding with dataset registration.${RESET}"
elif [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: failed to create policy (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
else
    echo -e "${BOLD}${GREEN}Policy created successfully.${RESET}"
fi
echo ""

echo -e "${DIM}Registering dataset...${RESET}"
response=$(curl --silent "$BASE_URL/dataspace/app-datasets" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data-raw '{
        "appId": "urn:app:dpi-frontiers",
        "dataset": {
            "@context": [
                "https://w3id.org/dspace/2025/1/context.jsonld",
                {
                    "dcterms": "http://purl.org/dc/terms/"
                }
            ],
            "@id": "https://frontiers.example.org/dataset-1",
            "@type": "Dataset",
            "dcterms:type": "https://vocabulary.uncefact.org/Consignment",
            "dcterms:publisher": "'"$PROVIDER_DID"'",
            "hasPolicy": [
                {
                    "@type": "Offer",
                    "@id": "urn:policy:test-policy-offer-1",
                    "assigner": "'"$PROVIDER_DID"'",
                    "permission": [
                        {
                            "action": "read",
                            "target": {
                                "@type": "twin:jsonPath",
                                "twin:jsonPathExpression": "$"
                            }
                        }
                    ]
                }
            ],
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

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -eq 409 ]; then
    echo -e "${YELLOW}Warning: dataset already exists, treating as provisioned.${RESET}"
    exit 0
elif [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: failed to register dataset (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

echo -e "${BOLD}${GREEN}Dataset registered successfully.${RESET}"
echo "$body" | jq . 2>/dev/null || echo "$body"
