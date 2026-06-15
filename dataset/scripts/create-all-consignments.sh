#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSIGNMENTS_DIR="$SCRIPT_DIR/../consignments"
BASE_URL="${BASE_URL:-http://localhost:3010}"

if [ "$#" -ne 2 ]; then
    echo "Usage: $(basename "$0") <email> <password>" >&2
    exit 1
fi

EMAIL="$1"
PASSWORD="$2"

echo "Authenticating..."
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
