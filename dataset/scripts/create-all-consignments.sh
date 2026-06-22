#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSIGNMENTS_DIR="$SCRIPT_DIR/../consignments"
AUTHN_FILE="$SCRIPT_DIR/../participants/provider-authn.json"
BASE_URL="${BASE_URL:-http://localhost:3010}"

YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

if [ "$#" -eq 2 ]; then
    EMAIL="$1"
    PASSWORD="$2"
elif [ "$#" -eq 0 ]; then
    if [ ! -f "$AUTHN_FILE" ]; then
        echo "Error: credentials file not found: $AUTHN_FILE" >&2
        exit 1
    fi
    EMAIL=$(jq -r '.email' "$AUTHN_FILE")
    PASSWORD=$(jq -r '.password' "$AUTHN_FILE")
else
    echo "Usage: $(basename "$0") [email password]" >&2
    exit 1
fi

echo -e "Authenticating as ${YELLOW}$EMAIL${RESET}..."
cookie=$(curl --silent --location "$BASE_URL/authentication/login" \
    --header 'Content-Type: application/json' \
    --data-raw "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" \
    --dump-header - \
    --output /dev/null \
    | grep -i '^set-cookie:' | sed 's/^[Ss]et-[Cc]ookie: //;s/;.*//')

if [ -z "$cookie" ]; then
    echo "Authentication failed" >&2
    exit 1
fi
echo "Authenticated."
echo ""

for file in "$CONSIGNMENTS_DIR"/consignment-1.jsonld "$CONSIGNMENTS_DIR"/consignment-2.jsonld "$CONSIGNMENTS_DIR"/consignment-3.jsonld; do
    name="$(basename "$file")"
    echo "Creating $name..."

    payload=$(jq -n \
        --argjson annotation "$(cat "$file")" \
        '{
            "@context": [
                "https://schema.twindev.org/aig/",
                "https://schema.twindev.org/common/"
            ],
            "type": "AuditableItemGraphVertex",
            "annotationObject": $annotation
        }')

    location=$(curl --silent --location "$BASE_URL/aig" \
        --header 'Content-Type: application/json' \
        --header "Cookie: $cookie" \
        --data-raw "$payload" \
        --dump-header - \
        --output /dev/null \
        | grep -i '^location:' | sed 's/^[Ll]ocation: //;s/\r//')

    aig_id="${location##*/}"
    aig_id="${aig_id//%3A/:}"
    aig_id="${aig_id//%2F//}"
    echo "AIG id: $aig_id"
    echo ""
done
