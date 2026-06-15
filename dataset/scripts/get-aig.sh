#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") <email> <password> <aig-id>" >&2
    echo "" >&2
    echo "  email      Login email" >&2
    echo "  password   Login password" >&2
    echo "  aig-id     AIG identifier (e.g. aig:019eb62ecaca732eb01b80793887b505)" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$#" -ne 3 ]; then
    usage
fi

EMAIL="$1"
PASSWORD="$2"
AIG_ID="$3"

BASE_URL="${BASE_URL:-http://localhost:3010}"

BOLD='\033[1m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

echo -e "${DIM}Authenticating...${RESET}"
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

encoded_id="${AIG_ID//:/%3A}"
encoded_id="${encoded_id//\//%2F}"

response=$(curl --silent "$BASE_URL/aig/$encoded_id/changesets" \
    --header "Cookie: $cookie" \
    --write-out "\n%{http_code}" )

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -eq 404 ]; then
    echo -e "${RED}Error: AIG '$AIG_ID' not found${RESET}" >&2
    exit 1
elif [ "$http_code" -ne 200 ]; then
    echo -e "${RED}Error: unexpected response (HTTP $http_code)${RESET}" >&2
    exit 1
fi

while IFS= read -r line; do
    version="${line%%:*}"
    proof_id="${line#*:}"

    encoded_proof_id="${proof_id//:/%3A}"
    encoded_proof_id="${encoded_proof_id//\//%2F}"

    proof_response=$(curl --silent "$BASE_URL/immutable-proof/$encoded_proof_id" \
        --header "Cookie: $cookie" \
        --write-out "\n%{http_code}")

    proof_http_code="${proof_response##*$'\n'}"
    proof_body="${proof_response%$'\n'*}"

    echo -e "${BOLD}${CYAN}$version${RESET}"
    if [ "$proof_http_code" -ne 200 ]; then
        echo -e "  ${YELLOW}notarizationId:${RESET}     ${RED}(unavailable)${RESET}"
        echo -e "  ${YELLOW}verificationMethod:${RESET} ${RED}(unavailable)${RESET}"
    else
        notarization_id=$(echo "$proof_body" | jq -r '.proof.notarizationId')
        verification_method=$(echo "$proof_body" | jq -r '.proof.verificationMethod')
        notarization_suffix="${notarization_id##*:}"
        
        echo -e "  ${YELLOW}notarizationId:${RESET}     ${GREEN}$notarization_id${RESET}"
        echo -e "  ${DIM}(https://explorer.iota.org/object/$notarization_suffix?network=testnet)${RESET}"
        identity_object="${verification_method%%#*}"
        identity_object="${identity_object##*:}"
        echo -e "  ${YELLOW}verificationMethod:${RESET} ${MAGENTA}$verification_method${RESET}"
        echo -e "  ${DIM}(https://explorer.iota.org/object/$identity_object?network=testnet)${RESET}"
    fi
    echo ""
done < <(echo "$body" | jq -r '.itemListElement | to_entries[] | "Version \(.key + 1):\(.value.proofId)"')
