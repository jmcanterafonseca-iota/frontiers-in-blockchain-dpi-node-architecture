curl --location 'http://localhost:3020/consumer-client/query-data' \
--header 'Content-Type: application/json' \
--data '{
    "entityType": "https://vocabulary.uncefact.org/Consignment",
    "agreementId": "urn:policy:019efa914b1074e08cd054e81091efb3",
    "entityId": ["6KEP051126254X"]
}'