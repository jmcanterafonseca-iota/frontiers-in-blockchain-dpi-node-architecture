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
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
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

response=$(curl --silent "$BASE_URL/aig" \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ]; then
    echo -e "${RED}Error: unexpected response (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

count=$(echo "$body" | jq -r '.itemListElement | length')
if [ "$count" -eq 0 ]; then
    echo -e "${YELLOW}No auditable item graphs found.${RESET}"
    exit 0
fi

echo -e "${BOLD}Auditable Item Graphs (${count}):${RESET}"
echo ""

while IFS=$'\t' read -r aig_id global_id; do
    echo -e "${BOLD}${CYAN}$aig_id${RESET}"
    echo -e "  ${YELLOW}annotationObject.globalId:${RESET} ${GREEN}$global_id${RESET}"
    echo ""
done < <(echo "$body" | jq -r '.itemListElement[] | "\(.id)\t\(.annotationObject.globalId // "")"')
