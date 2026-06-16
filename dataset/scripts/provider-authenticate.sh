curl --location 'http://localhost:3010/authentication/login' \
--header 'Content-Type: application/json' \
--data-raw '{
    "email": "admin-provider@node",
    "password": "1234-A-1234-b-1234"
}'
