curl --location 'http://localhost:3010/rights-management/policy/admin' \
--header 'Content-Type: application/json' \
--header 'Cookie: access_token=eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkaWQ6aW90YTp0ZXN0bmV0OjB4MDNiMDY2Yzc0NWIzZDY3NTY5YjVjYjRjMDFkZmQzOWQ4MzU3M2IwNjE3ZWZhN2M5NDk5YTcyMjBlY2MzMDJmZCIsIm9yZyI6ImRpZDppb3RhOnRlc3RuZXQ6MHhiMDhjNzZmZTM0MmVhYjg3YmIxNmVmNmVjNzAyNzRjYTcyZDE1ZGVmZGU3ZjAwZmM0MmIzMGZkNzBlNmFjMzhlIiwiZXhwIjoxNzgxNTEyODUzLCJzY29wZSI6InRlbmFudC1hZG1pbix1c2VyLWFkbWluIiwicHZlciI6MH0.ZNlPq4YxU_--01dptWzQJS602fCUOb6Az8xahrcj4Cq-aB1vVEc2u8_8f_8A3rmMDldbbLNH4JAwxhOoFLuhAA' \
--data-raw '{
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "Offer",
    "@id": "urn:policy:test-policy-offer-1",
    "uid": "urn:policy:test-policy-offer-1",
    "target": "https://frontiers.example.org/dataset-1",
    "assigner": "did:iota:testnet:0xb08c76fe342eab87bb16ef6ec70274ca72d15defde7f00fc42b30fd70e6ac38e",
    "permission": [
        {
            "action": "use"
        }
    ]
}'