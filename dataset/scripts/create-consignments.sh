#!/usr/bin/env bash
# =============================================================================
# create-consignments.sh — Write two Consignment vertices into the provider's
# Auditable Item Graph (demonstration of the AIG; the dataspace pull serves the
# dataspace-example-app's own consignments, not these).
#
# Post-#203: /aig requires auth (Bearer session token). Login is email+password
# only on a single-org node; the org is auto-injected, ?organization is optional.
# =============================================================================
set -euo pipefail

PROVIDER_HOST="${PROVIDER_HOST:-http://localhost:3010}"
PROVIDER_CONTAINER="${PROVIDER_CONTAINER:-dpi_node_provider}"
PROVIDER_EMAIL="${PROVIDER_EMAIL:-admin-provider@node}"
PROVIDER_PASSWORD="${PROVIDER_PASSWORD:-1234-A-1234-b-1234}"

SESS=$(curl -sS -i -X POST "${PROVIDER_HOST}/authentication/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${PROVIDER_EMAIL}\",\"password\":\"${PROVIDER_PASSWORD}\"}" \
    | grep -i '^set-cookie:' | grep -oE 'access_token=[^;]+' | head -1 | cut -d= -f2-)
[ -n "$SESS" ] || { echo "login failed"; exit 1; }
ORG_ENC=$(docker exec "${PROVIDER_CONTAINER}" sh -c 'cat /var/lib/twin/engine-state.json' 2>/dev/null \
    | jq -r '.nodeOrganizationId // empty' | jq -rR '@uri')

curl --location "${PROVIDER_HOST}/aig?organization=${ORG_ENC}" \
--header 'Content-Type: application/json' \
--header "Authorization: Bearer ${SESS}" \
--data-raw '{
    "@context": [
        "https://schema.twindev.org/aig/",
        "https://schema.twindev.org/common/"
    ],
    "type": "AuditableItemGraphVertex",
    "annotationObject": {
        "@context": "https://vocabulary.uncefact.org/unece-context-D23B.jsonld",
        "type": "Consignment",
        "identifier": "250412-001",
        "globalId": "6PLB12345678INV2026001",
        "summaryDescription": "Fresh chicken",
        "exporterParty": {
            "type": "TradeParty",
            "identifier": {
                "@type": "https://ref.gs1.org/voc/OrganizationID_Type-EORI",
                "@value": "PL39000000004358Z"
            }
        },
        "importerParty": {
            "type": "TradeParty",
            "identifier": {
                "@type": "https://ref.gs1.org/voc/OrganizationID_Type-EORI",
                "@value": "GB362012792073"
            }
        },
        "includedConsignmentItem": [
            {
                "type": "ConsignmentItem",
                "exportTypeCode": "1602329090"
            }
        ],
        "originCountry": {
            "countryId": "unece:CountryId#PL"
        },
        "destinationCountry": {
            "countryId": "unece:CountryId#GB"
        },
        "packageQuantity": {
            "type": "QuantityType",
            "unece:QuantityTypeValue": 25
        },
        "weightUnitNetWeightMeasure": [
            {
                "type": "WeightUnitMeasureType",
                "unece:WeightUnitMeasureTypeValue": "19578",
                "unece:WeightUnitMeasureTypeCode": "unece:WeightUnitMeasureCode#KGM"
            }
        ],
        "utilizedTransportEquipment": [
            {
                "type": "LogisticsTransportEquipment",
                "affixedSeal": [
                    {
                        "type": "Seal",
                        "identifier": "TX1138"
                    }
                ],
                "specifiedTransportMeans": [
                    {
                        "identifier": "DSW450AE",
                        "type": "LogisticsTransportMeans",
                        "transportMeansTypeCode": "unece:TransportMeansTypeCodeList#3103",
                        "driverAccompaniedIndicator": true
                    }
                ]
            }
        ],
        "atDepartureTransportMovement": {
            "type": "TransportMovement",
            "departureEvent": [
                {
                    "type": "TransportEvent",
                    "occurrenceLogisticsLocation": {
                        "type": "LogisticsLocation",
                        "identifier": {
                            "@type": "https://ref.gs1.org/voc/LocationID_Type-UN_LOCODE",
                            "@value": "NLRTM"
                        }
                    },
                    "scheduledOccurrenceDateTime": "2026-05-8T19:00:00Z"
                }
            ],
            "transportModeCode": "unece:TransportModeCodeList#1",
            "carrierParty": {
                "type": "TradeParty",
                "name": "DFDS"
            },
            "usedTransportMeans": {
                "identifier": "Belgia Seaways",
                "transportMeansTypeCode": "unece:TransportMeansTypeCodeList#1512"
            }
        },
        "atArrivalTransportMovement": {
            "type": "TransportMovement",
            "arrivalEvent": [
                {
                    "type": "TransportEvent",
                    "occurrenceLogisticsLocation": {
                        "type": "LogisticsLocation",
                        "identifier": {
                            "@type": "https://ref.gs1.org/voc/LocationID_Type-UN_LOCODE",
                            "@value": "GBFXT"
                        }
                    },
                    "scheduledOccurrenceDateTime": "2026-05-09T07:00:00Z"
                }
            ],
            "transportModeCode": "unece:TransportModeCodeList#1"
        }
    }
}'

curl --location "${PROVIDER_HOST}/aig?organization=${ORG_ENC}" \
--header 'Content-Type: application/json' \
--header "Authorization: Bearer ${SESS}" \
--data-raw '{
    "@context": [
        "https://schema.twindev.org/aig/",
        "https://schema.twindev.org/common/"
    ],
    "type": "AuditableItemGraphVertex",
    "annotationObject": {
        "type": "Create",
        "object": {
            "@context": "https://vocabulary.uncefact.org/unece-context-D23B.jsonld",
            "type": "Consignment",
            "identifier": "A44-5566",
            "globalId": "6KEP051126254X",
            "summaryDescription": "Fresh cut flowers",
            "exporterParty": {
                "type": "TradeParty",
                "identifier": {
                    "@type": "https://ref.gs1.org/voc/OrganizationID_Type-CRN",
                    "@value": "P00011000"
                }
            },
            "importerParty": {
                "type": "TradeParty",
                "identifier": {
                    "@type": "https://ref.gs1.org/voc/OrganizationID_Type-NL_KVK_NUMBER",
                    "@value": "12345678"
                }
            },
            "includedConsignmentItem": [
                {
                    "type": "ConsignmentItem",
                    "exportTypeCode": "0603.11"
                }
            ],
            "originCountry": {
                "countryId": "unece:CountryId#KE"
            },
            "destinationCountry": {
                "countryId": "unece:CountryId#NL"
            },
            "packageQuantity": {
                "type": "QuantityType",
                "unece:QuantityTypeValue": 25
            },
            "weightUnitNetWeightMeasure": [
                {
                    "type": "WeightUnitMeasureType",
                    "unece:WeightUnitMeasureTypeValue": "345",
                    "unece:WeightUnitMeasureTypeCode": "unece:WeightUnitMeasureCode#KGM"
                }
            ],
            "atDepartureTransportMovement": {
                "type": "TransportMovement",
                "departureEvent": [
                    {
                        "type": "TransportEvent",
                        "occurrenceLogisticsLocation": {
                            "type": "LogisticsLocation",
                            "identifier": {
                                "@type": "https://ref.gs1.org/voc/LocationID_Type-IATA_CODE",
                                "@value": "NBO"
                            }
                        },
                        "scheduledOccurrenceDateTime": "2026-05-8T19:00:00Z"
                    }
                ],
                "transportModeCode": "unece:TransportModeCodeList#4",
                "carrierParty": {
                    "type": "TradeParty",
                    "name": "KLM"
                },
                "usedTransportMeans": {
                    "identifier": "KLM23456",
                    "transportMeansTypeCode": "unece:TransportMeansTypeCodeList#4000"
                }
            },
            "atArrivalTransportMovement": {
                "type": "TransportMovement",
                "arrivalEvent": [
                    {
                        "type": "TransportEvent",
                        "occurrenceLogisticsLocation": {
                            "type": "LogisticsLocation",
                            "identifier": {
                                "@type": "https://ref.gs1.org/voc/LocationID_Type-IATA_CODE",
                                "@value": "AMS"
                            }
                        },
                        "scheduledOccurrenceDateTime": "2026-05-09T07:00:00Z"
                    }
                ],
                "transportModeCode": "unece:TransportModeCodeList#4"
            }
        },
        "actor": {
            "type": "TradeParty",
            "registeredId": {
                "@type": "https://ref.gs1.org/voc/OrganizationID_Type-DID",
                "@value": "did:iota:123456"
            },
            "@context": "https://vocabulary.uncefact.org/unece-context-D23B.jsonld"
        },
        "@context": [
            "https://www.w3.org/ns/activitystreams"
        ],
        "generator": "did:iota:123456",
        "updated": "2026-02-12T19:19:01.338Z",
        "name": "Pre-Notification"
    }
}'
