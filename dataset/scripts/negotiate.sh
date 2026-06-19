#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") <email> <password>" >&2
    echo "" >&2
    echo "  email      Login email" >&2
    echo "  password   Login password" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$#" -ne 2 ]; then
    usage
fi

EMAIL="${1:-admin@node}"
PASSWORD="$2"

BASE_URL="${BASE_URL:-http://localhost:3020}"
AUTH_URL="${AUTH_URL:-http://localhost:3020}"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

echo -e "${DIM}Authenticating...${RESET}"
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

echo -e "${DIM}Negotiating...${RESET}"
response=$(curl --silent "$BASE_URL/consumer-client/negotiate" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data '{
        "entityType": "https://vocabulary.uncefact.org/Consignment"
    }')

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: negotiation failed (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

agreement_id=$(echo "$body" | jq -r '.agreementId')

echo -e "${BOLD}${CYAN}Agreement ID:${RESET} ${GREEN}$agreement_id${RESET}"
