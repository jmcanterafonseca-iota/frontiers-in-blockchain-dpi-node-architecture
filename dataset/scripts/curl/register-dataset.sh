curl --location 'http://localhost:3010/dataspace/app-datasets' \
--header 'Content-Type: application/json' \
--data-raw '{
    "appId": "urn:app:dpi-frontiers",
    "dataset": {
        "@context": [
            "https://w3id.org/dspace/2025/1/context.jsonld",
            {
                "dcterms": "http://purl.org/dc/terms/"
            }
        ],
        "@id": "https://frontiers.example.org/dataset-1",
        "@type": "Dataset",
        "dcterms:type": "https://vocabulary.uncefact.org/Consignment",
        "dcterms:publisher": "did:iota:testnet:0xb08c76fe342eab87bb16ef6ec70274ca72d15defde7f00fc42b30fd70e6ac38e",
        "hasPolicy": [
            {
                "@type": "Offer",
                "@id": "urn:policy:test-policy-offer-1",
                "assigner": "did:iota:testnet:0xb08c76fe342eab87bb16ef6ec70274ca72d15defde7f00fc42b30fd70e6ac38e",
                "permission": [
                    {
                        "action": "use"
                    }
                ]
            }
        ],
        "distribution": {
            "@id": "https://twin.example.org/distribution-1",
            "@type": "Distribution",
            "accessService": {
                "@id": "urn:uuid:4aa2dcc8-4d2d-569e-d634-8394a8834d77",
                "@type": "DataService",
                "endpointURL": "http://localhost:3010"
             },
            "format": "HttpData-PULL"
        }
    }
}'