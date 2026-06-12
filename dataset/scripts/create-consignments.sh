curl --location 'http://localhost:3010/aig' \
--header 'Content-Type: application/json' \
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

curl --location 'http://localhost:3010/aig' \
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