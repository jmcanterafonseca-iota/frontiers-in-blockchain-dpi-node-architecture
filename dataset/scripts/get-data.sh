#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") <negotiation-id> <entity-type> [entity-id] [email password]" >&2
    echo "" >&2
    echo "  negotiation-id  Agreement id to retrieve data for (e.g. urn:policy:019ef...)" >&2
    echo "  entity-type     Entity type to query (e.g. https://vocabulary.uncefact.org/Consignment)" >&2
    echo "  entity-id       Optional entity id to filter the query (e.g. 6KEP051126254X)" >&2
    echo "  email           Login email (default: from consumer-authn.json)" >&2
    echo "  password        Login password (default: from consumer-authn.json)" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

# Mandatory: negotiation-id, entity-type. Optional: entity-id and/or an email+password pair.
# Accepted argument counts:
#   2 -> negotiation-id entity-type
#   3 -> negotiation-id entity-type entity-id
#   4 -> negotiation-id entity-type email password
#   5 -> negotiation-id entity-type entity-id email password
if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
    usage
fi

NEGOTIATION_ID="$1"
ENTITY_TYPE="$2"
ENTITY_ID=""
EMAIL=""
PASSWORD=""

case "$#" in
    2)
        ;;
    3)
        ENTITY_ID="$3"
        ;;
    4)
        EMAIL="$3"
        PASSWORD="$4"
        ;;
    5)
        ENTITY_ID="$3"
        EMAIL="$4"
        PASSWORD="$5"
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTHN_FILE="$SCRIPT_DIR/../participants/consumer-authn.json"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
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

# Build the query body. entityId is only included when an entity id was supplied.
if [ -n "$ENTITY_ID" ]; then
    payload=$(jq -n --arg et "$ENTITY_TYPE" --arg aid "$NEGOTIATION_ID" --arg eid "$ENTITY_ID" \
        '{entityType: $et, agreementId: $aid, entityId: [$eid]}')
else
    payload=$(jq -n --arg et "$ENTITY_TYPE" --arg aid "$NEGOTIATION_ID" \
        '{entityType: $et, agreementId: $aid}')
fi

echo -e "${DIM}Retrieving data for negotiation ${RESET}${YELLOW}$NEGOTIATION_ID${RESET}${DIM}...${RESET}"
response=$(curl --silent "$BASE_URL/consumer-client/query-data" \
    --header 'Content-Type: application/json' \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" \
    --data "$payload")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -ne 200 ] && [ "$http_code" -ne 201 ]; then
    echo -e "${RED}Error: failed to retrieve data (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

# The response is an object whose consignments are listed under itemListElement.
# Print each one's globalId together with the origin and destination country.
rows=$(echo "$body" | jq -r '
    .itemListElement[]
    | [.globalId, (.originCountry.countryId // "-"), (.destinationCountry.countryId // "-")]
    | @tsv' 2>/dev/null)

if [ -z "$rows" ]; then
    echo -e "${YELLOW}No consignments found in the response.${RESET}"
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 0
fi

echo -e "${BOLD}${CYAN}Consignments:${RESET}"
echo ""
while IFS=$'\t' read -r global_id origin dest; do
    echo -e "${BOLD}${YELLOW}globalId:${RESET}           ${GREEN}$global_id${RESET}"
    echo -e "${BOLD}${YELLOW}originCountry:${RESET}      ${GREEN}$origin${RESET}"
    echo -e "${BOLD}${YELLOW}destinationCountry:${RESET} ${GREEN}$dest${RESET}"
    echo ""
done <<< "$rows"
