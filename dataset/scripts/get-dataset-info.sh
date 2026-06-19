#!/bin/bash

usage() {
    echo "Usage: $(basename "$0") <dataset-id>" >&2
    echo "" >&2
    echo "  dataset-id   Dataset identifier (e.g. https://frontiers.example.org/dataset-1)" >&2
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$#" -ne 1 ]; then
    usage
fi

DATASET_ID="$1"

BASE_URL="${BASE_URL:-http://localhost:3010}"

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JWT_FILE="$SCRIPT_DIR/../participants/provider-trust-token.jwt"

echo -e "${DIM}Reading trust token from $JWT_FILE...${RESET}"
if [ ! -f "$JWT_FILE" ]; then
    echo -e "${RED}Trust token file not found: $JWT_FILE${RESET}" >&2
    exit 1
fi

trust_token=$(cat "$JWT_FILE")

if [ -z "$trust_token" ]; then
    echo -e "${RED}Trust token file is empty${RESET}" >&2
    exit 1
fi

echo -e "${DIM}Trust token read from:${RESET} $JWT_FILE"
echo ""

encoded_id="${DATASET_ID//:/%3A}"
encoded_id="${encoded_id//\//%2F}"

echo -e "${DIM}GET $BASE_URL/federated-catalogue/datasets/$encoded_id${RESET}"
response=$(curl --silent "$BASE_URL/federated-catalogue/datasets/$encoded_id" \
    --header "Authorization: Bearer $trust_token" \
    --write-out "\n%{http_code}")

http_code="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$http_code" -eq 404 ]; then
    echo -e "${RED}Error: dataset not found${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
elif [ "$http_code" -ne 200 ]; then
    echo -e "${RED}Error: unexpected response (HTTP $http_code)${RESET}" >&2
    echo "$body" | jq . 2>/dev/null || echo "$body"
    exit 1
fi

echo -e "${BOLD}${GREEN}Dataset info:${RESET}"
echo "$body" | jq .
