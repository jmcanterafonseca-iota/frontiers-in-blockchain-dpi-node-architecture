#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") <entity-type> [email password]" >&2
    echo "" >&2
    echo "  entity-type  Entity type to negotiate for (e.g. https://vocabulary.uncefact.org/Consignment)" >&2
    echo "  email        Login email (default: from consumer-authn.json)" >&2
    echo "  password     Login password (default: from consumer-authn.json)" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; then
    usage
fi

ENTITY_TYPE="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTHN_FILE="$SCRIPT_DIR/../participants/consumer-authn.json"

if [ "$#" -eq 3 ]; then
    EMAIL="$2"
    PASSWORD="$3"
else
    if [ ! -f "$AUTHN_FILE" ]; then
        echo "Error: credentials file not found: $AUTHN_FILE" >&2
        exit 1
    fi
    EMAIL=$(jq -r '.email' "$AUTHN_FILE")
    PASSWORD=$(jq -r '.password' "$AUTHN_FILE")
fi

BASE_URL="${BASE_URL:-http://localhost:3020}"
AUTH_URL="${AUTH_URL:-http://localhost:3020}"

BOLD='\033[1m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

echo -e "${DIM}Authenticating as ${RESET}${YELLOW}$EMAIL${RESET}${DIM}...${RESET}"
cookie=$(curl --silent "$AUTH_URL/authentication/login" \
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

echo -e "${DIM}Negotiating for entity type ${RESET}${YELLOW}$ENTITY_TYPE${RESET}${DIM}...${RESET}"
response=$(curl --silent "$BASE_URL/consumer-client/negotiate" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data "{\"entityType\": \"$ENTITY_TYPE\"}")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: negotiation failed (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

agreement_id=$(echo "$body" | jq -r '.agreementId')

echo -e "${BOLD}${CYAN}Agreement ID:${RESET} ${GREEN}$agreement_id${RESET}"
