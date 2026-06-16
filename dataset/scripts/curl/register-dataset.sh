curl --location 'http://localhost:3010/dataspace/app-datasets' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6aW90YTp0ZXN0bmV0OjB4MDNiMDY2Yzc0NWIzZDY3NTY5YjVjYjRjMDFkZmQzOWQ4MzU3M2IwNjE3ZWZhN2M5NDk5YTcyMjBlY2MzMDJmZCIsIm9yZyI6ImRpZDppb3RhOnRlc3RuZXQ6MHhiMDhjNzZmZTM0MmVhYjg3YmIxNmVmNmVjNzAyNzRjYTcyZDE1ZGVmZGU3ZjAwZmM0MmIzMGZkNzBlNmFjMzhlIiwiZXhwIjoxNzgxMTk2MTk1LCJzY29wZSI6InRlbmFudC1hZG1pbix1c2VyLWFkbWluIiwicHZlciI6MH0._GFJkDaDw_nInZnTl3RwdNIb67Jm4OIRRnlfPwBmzwwW40ST5FTiL7cxWoqyk45QTebybNCfmxv3Vee6Bq1ABw' \
--header 'Cookie: access_token=eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6aW90YTp0ZXN0bmV0OjB4MDNiMDY2Yzc0NWIzZDY3NTY5YjVjYjRjMDFkZmQzOWQ4MzU3M2IwNjE3ZWZhN2M5NDk5YTcyMjBlY2MzMDJmZCIsIm9yZyI6ImRpZDppb3RhOnRlc3RuZXQ6MHhiMDhjNzZmZTM0MmVhYjg3YmIxNmVmNmVjNzAyNzRjYTcyZDE1ZGVmZGU3ZjAwZmM0MmIzMGZkNzBlNmFjMzhlIiwiZXhwIjoxNzgxNTEyODUzLCJzY29wZSI6InRlbmFudC1hZG1pbix1c2VyLWFkbWluIiwicHZlciI6MH0.ZNlPq4YxU_--01dptWzQJS602fCUOb6Az8xahrcj4Cq-aB1vVEc2u8_8f_8A3rmMDldbbLNH4JAwxhOoFLuhAA' \
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