# DPI Dataspace (2-node) Postman Walkthrough

> Created: 2026-06-19
> Last updated: 2026-06-24

End-to-end DSP data sharing across **two** TWIN nodes (a provider and a consumer) for the `frontiers-in-blockchain-dpi-node-architecture` demo. Two files in this directory:

- `DPI-Dataspace.postman_collection.json` (import into Postman)
- `DPI-Dataspace.postman_environment.json` (import as a Postman environment, then select it)

The flow: the **provider** publishes an ODRL offer plus a dataset into its federated catalogue; the **consumer** discovers the dataset, negotiates a contract to `FINALIZED`, then pulls the data with a single consumer-client `query-data` call. The provider runs `DPI_NODE_DATASPACE_AUTO_START_TRANSFERS="true"`, so `query-data` drives the whole transfer (request, provider auto-start, start callback, consumer pull) in one step. Every request's **Tests** tab extracts the one value the next request needs (session cookie, trust JWT, agreement id), so you can run the collection top to bottom.

Every request below has also been verified by running it as a raw `curl` against a live 2-node stack (the companion `dataset/scripts/run-flow.sh` automates the same provision, negotiate, `query-data` pull flow).

---

## Prerequisites

1. **Stack up on the published image.** `docker-compose.yaml` pins `twinfoundation/twin-node:0.0.3-next.56` (carries the organization-identifiers refactor `#19/#203`). Provider is published on host port `3010`, consumer on `3020`.

2. **Both nodes bootstrapped.** Bootstrap creates each node's IOTA identity, organization identity (with a `trust-assertion` verification method), and admin user:
   ```sh
   docker compose run --rm -T dpi-node-provider \
     sh -c 'node src/index.js bootstrap-legacy --load-env=./.env.bootstrap,.env.bootstrap.provider --env-prefix=DPI_NODE_'
   docker compose run --rm -T dpi-node-consumer \
     sh -c 'node src/index.js bootstrap-legacy --load-env=./.env.bootstrap,.env.bootstrap.consumer --env-prefix=DPI_NODE_'
   docker compose up -d
   ```
   (`node-admin.sh <provider|consumer> bootstrap-legacy` wraps the same command but needs a TTY.)

3. **Config that the data-serving (provider) side needs**, already set in `environment/common/.env`:
   - `DPI_NODE_RIGHTS_MANAGEMENT_POLICY_ARBITERS="default"` and `..._POLICY_ENFORCEMENT_PROCESSORS="default"` (the data-plane pull runs the Policy Decision Point; without an arbiter it returns `noArbiters`).
   - `DPI_NODE_RIGHTS_MANAGEMENT_POLICY_REQUESTERS="pass-through"` and `..._POLICY_OBLIGATION_ENFORCERS="pass-through"`.
   - `DPI_NODE_DATASPACE_DATA_PLANE_PATH="dataspace"` (the data-plane **base** mount; the entities resource lives at `<base>/entities`, which the data-plane client appends itself). The DSP transfer channel (`dataAddress.endpoint`) is `<publicOrigin>/dataspace`. Without this set the pull returns `pullTransfersNotSupported`.
   - Provider only: `DPI_NODE_DATASPACE_AUTO_START_TRANSFERS="true"` so the provider auto-starts a requested transfer (drives the single-call `query-data` flow).
   - Provider only: `DPI_NODE_PUBLIC_ORIGIN="http://dpi_node_provider:3000"` in `environment/provider/.env.provider` so the data-pull endpoint it advertises is reachable on the docker network.

4. **Consumer-client extension config** (in `apps/consumer-client`, already built into `dist/`): the remote federated catalogue is the consumer's default catalogue (so the control plane can validate the offer against the provider catalogue), and a static Policy Information source is registered (so the negotiation trust token has a non-empty subject). See the troubleshooting notes below for why.

---

## Environment variables

Pre-filled in the environment JSON. Overwrite per your setup.

| Var | Value (this demo) | Notes |
|---|---|---|
| `prov_base` | `http://localhost:3010` | provider node, from the host |
| `cons_base` | `http://localhost:3020` | consumer node, from the host |
| `prov_net` | `http://dpi_node_provider:3000` | provider's address on the docker network (baked into the dataset endpoint) |
| `cons_net` | `http://dpi_node_consumer:3000` | consumer's address on the docker network (transfer callback) |
| `prov_email` / `cons_email` | `admin-provider@node` / `admin@node` | from `.env.bootstrap.*` |
| `prov_password` / `cons_password` | `1234-A-1234-b-1234` | from `.env.bootstrap.*` |
| `prov_did` / `cons_did` | `did:iota:testnet:0x…` | each node's **organization DID**. Changes on every fresh bootstrap, refresh it (see below). |
| `dataset_id` | `https://twin.example.org/dpi-consignment` | the published dataset |
| `dataset_type` | `https://vocabulary.uncefact.org/Consignment` | matches `TestDataspaceDataPlaneApp` |
| `offer_id` | `urn:policy:dpi-consignment-offer` | ODRL offer id |
| `app_id` | `urn:app:dpi-frontiers` | matches `TestDataspaceDataPlaneApp.APP_ID` |
| `trust_vm` | `trust-assertion` | verification method used for trust JWTs |

Populated as you run (extraction scripts handle these): `prov_session_jwt`, `cons_session_jwt`, `prov_trust_jwt`, `cons_trust_jwt`, `agreement_id`, `access_token`.

### Refreshing the DIDs after a bootstrap

The org DIDs are minted on IOTA testnet and differ every fresh bootstrap. Read them from each node's engine state and paste into the environment:
```sh
docker exec dpi_node_provider sh -c 'cat /var/lib/twin/engine-state.json' | jq -r .nodeOrganizationId   # -> prov_did
docker exec dpi_node_consumer sh -c 'cat /var/lib/twin/engine-state.json' | jq -r .nodeOrganizationId   # -> cons_did
```

---

## How the collection wires requests together

Each request has a **Tests** script that writes one value to the environment with `pm.environment.set(...)`. Login requests grab the `access_token` cookie; trust-mint requests grab `response.jwt`; `C2` grabs `agreementId`; `D1` (`query-data`) consumes the `agreement_id` and returns the data directly. The next request references the value via `{{name}}`. To see what populated, click the eye icon next to the environment dropdown. If a script did not run (no environment selected, re-import quirk), copy the value from the response body into the env var's **Current value** column by hand.

## Auth model (post-#203)

- **Login** (`/authentication/login`) is email + password only. The token comes back as a `Set-Cookie: access_token=...`.
- Every **other** request carries `?organization=<org-did>`. On these single-org nodes the node injects its own org automatically, so the param is optional, but if present it must match. We pass it explicitly for clarity.
- The caller is identified by a **trust JWT** (`Authorization: Bearer <trust-jwt>`) on cross-org requests (the catalogue query). Admin writes on your own node (offer, dataset) accept the session token (`Authorization: Bearer <session-jwt>`); the consumer-client routes (`/consumer-client/negotiate`, `/consumer-client/query-data`) use the consumer session cookie.

---

## A. Provider setup (one-time)

### A1. Login as provider
`POST {{prov_base}}/authentication/login` with `{ "email": "{{prov_email}}", "password": "{{prov_password}}" }`.
Extracts `access_token` cookie into `prov_session_jwt`.

### A2. Mint provider trust JWT-VC
`POST {{prov_base}}/identity/{{prov_did}}/verifiable-credential/{{trust_vm}}?organization={{prov_did}}`, header `Cookie: access_token={{prov_session_jwt}}`, body `{ "subject": { "id": "{{prov_did}}" } }`.
Extracts `response.jwt` into `prov_trust_jwt`. Not needed by the auto-start `query-data` flow (the provider mints its own credential when it auto-starts the transfer); kept for completeness and manual DSP calls.

### A3. Create ODRL Offer
`POST {{prov_base}}/rights-management/policy/admin?organization={{prov_did}}`, header `Authorization: Bearer {{prov_session_jwt}}`.
```json
{
  "@context": "http://www.w3.org/ns/odrl.jsonld",
  "@type": "Offer",
  "@id": "{{offer_id}}",
  "assigner": "{{prov_did}}",
  "target": "{{dataset_id}}",
  "action": "read",
  "permission": [
    { "action": "read", "target": { "@type": "twin:jsonPath", "twin:jsonPathExpression": "$" } }
  ]
}
```
The permission **target must be a `twin:jsonPath` expression** (`$` selects the whole record). The data-plane arbiter rejects a plain dataset-id target with `ruleTargetNotSupported`. Expect `201` (or `409` if already seeded). To re-seed after editing, delete first: `DELETE /rights-management/policy/admin/<url-encoded offer_id>`.

### A4. Register Dataset
`POST {{prov_base}}/dataspace/app-datasets?organization={{prov_did}}`, header `Authorization: Bearer {{prov_session_jwt}}`.
```json
{
  "appId": "{{app_id}}",
  "dataset": {
    "@context": { "dcat": "http://www.w3.org/ns/dcat#", "dcterms": "http://purl.org/dc/terms/", "odrl": "http://www.w3.org/ns/odrl/2/" },
    "@type": "dcat:Dataset",
    "@id": "{{dataset_id}}",
    "dcterms:title": "DPI Consignment Dataset",
    "dcterms:type": "{{dataset_type}}",
    "dcterms:publisher": "{{prov_did}}",
    "dcat:distribution": {
      "@type": "dcat:Distribution",
      "dcterms:format": "application/json",
      "dcat:accessService": { "@id": "{{prov_net}}/rights-management", "@type": "dcat:DataService", "dcat:endpointURL": "{{prov_net}}/" }
    },
    "odrl:hasPolicy": {
      "@context": "http://www.w3.org/ns/odrl.jsonld", "@type": "Offer", "@id": "{{offer_id}}",
      "assigner": "{{prov_did}}", "target": "{{dataset_id}}", "action": "read",
      "permission": [ { "action": "read", "target": { "@type": "twin:jsonPath", "twin:jsonPathExpression": "$" } } ]
    }
  }
}
```
The base path is `/dataspace` on the provider (the consumer renames its own control plane to `/dataspace-control-plane`). `dcat:endpointURL` is the provider's **docker-network** address (`{{prov_net}}/`), so the consumer container can reach it; the catalogue bakes `?organization={{prov_did}}` onto it at publish time. `appId` must match a registered dataspace app. Expect `201` (or `409`). Re-seed with `DELETE /dataspace/app-datasets/<url-encoded dataset_id>`.

---

## B. Consumer setup (one-time)

### B1. Login as consumer
`POST {{cons_base}}/authentication/login` with `{ "email": "{{cons_email}}", "password": "{{cons_password}}" }`. Extracts `cons_session_jwt`.

### B2. Mint consumer trust JWT-VC
`POST {{cons_base}}/identity/{{cons_did}}/verifiable-credential/{{trust_vm}}?organization={{cons_did}}`, header `Cookie: access_token={{cons_session_jwt}}`, body `{ "subject": { "id": "{{cons_did}}" } }`. Extracts `cons_trust_jwt`. Identifies the consumer to the provider on the catalogue query (`C1`).

---

## C. Discover + negotiate

### C1. Query the federated catalogue (optional)
`POST {{prov_base}}/federated-catalogue/request?organization={{prov_did}}`, header `Authorization: Bearer {{cons_trust_jwt}}`.
```json
{ "@context": ["https://w3id.org/dspace/2025/1/context.jsonld"], "@type": "CatalogRequestMessage", "filter": [] }
```
Illustrative: the consumer reads the provider's catalogue and sees the dataset. This raw request uses an empty filter, but the provider now registers a `filter-by-metadata` handler (via `DPI_NODE_FEDERATED_CATALOGUE_FILTERS="filter-by-metadata"`), and the consumer-client filters the catalogue by `dcterms:type` using a `FilterByMetadata` filter. Expect `200` with the dataset present and its `endpointURL` baked with `?organization=`.

### C2. Negotiate (consumer-client)
`POST {{cons_base}}/consumer-client/negotiate`, header `Cookie: access_token={{cons_session_jwt}}`, body `{}`.
Drives the whole DSP contract negotiation in-process on the consumer node (`REQUESTED -> OFFERED -> ACCEPTED -> AGREED -> VERIFIED -> FINALIZED`) and returns `{ "agreementId": "..." }`. Extracts `agreement_id`. This is the consumer-client extension's job and the simplest way to obtain an agreement.

---

## D. Transfer + retrieve

### D1. Query data (consumer-client, provider auto-start)
`POST {{cons_base}}/consumer-client/query-data`, header `Cookie: access_token={{cons_session_jwt}}`.
```json
{ "agreementId": "{{agreement_id}}", "entityType": "{{dataset_type}}" }
```
A single call that drives the whole transfer. The provider runs `DPI_NODE_DATASPACE_AUTO_START_TRANSFERS="true"`, so this request triggers: consumer requests the transfer, provider **auto-starts** it and POSTs the `TransferStartMessage` to the consumer's control-plane callback, the consumer-client's `onStarted` pulls the entities via the data-plane client, and the data is returned in the response. (The old manual two-step start is incompatible with auto-start mode: a manual provider-start call now fails with `UnauthorizedError:dataspaceControlPlaneService.callerNotAuthorizedAsProvider` because the provider already auto-started it.)

The response shape is:
```json
{ "itemList": { "@context": "...", "type": "ItemList", "itemListElement": [ { /* consignment */ }, ... ] } }
```
Expect `200` with `itemList.itemListElement.length >= 1` (2 consignments in this demo).

> **`query-data` timeout caveat:** the provider's auto-start mints the transfer-start verifiable credential with its own vault key (`runProviderStart`). If that mint fails, `query-data` hangs until a stalled-transfer cleanup fires (minutes later). The deterministic cause is provisioning, not testnet flakiness: the offer assigner (and dataset publisher) must match the provider's **current** node identity. If the dataset/offer was provisioned under an identity the provider no longer controls, the provider cannot mint the start credential. Re-run `register-dataset.sh` (it resolves the provider's current `nodeOrganizationId` dynamically and uses a `twin:jsonPath` policy target), then retry.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `nodeIdentityNotSet` on startup | server started before bootstrap | run `bootstrap-legacy` (Prereq 2) before `docker compose up -d` |
| login returns no cookie | wrong email/password, or old bootstrap feature flags | `DPI_NODE_FEATURES` must be `"admin-user,wallet"`; creds from `.env.bootstrap.*` |
| `datasetNotFoundInCatalog` on negotiate | consumer's control plane reading its own (empty) catalogue | the consumer-client makes the **remote** catalogue its default (`extension.ts`) |
| `verifiableCredentialCreate ... guard.objectValue` (empty `subject`) on negotiate | no Policy Information source, so the trust subject is `{}` | consumer-client registers a static PIP source (`extension.ts`) |
| `policyDecisionPointService.noArbiters` on pull | no arbiter on the provider | set `..._POLICY_ARBITERS="default"` (Prereq 3) |
| `defaultPolicyArbiter.ruleTargetNotSupported` on pull | offer permission target is a plain URL | use a `twin:jsonPath` target (`A3`/`A4`) |
| `pullTransfersNotSupported` on pull | data-plane path not set | `DPI_NODE_DATASPACE_DATA_PLANE_PATH="dataspace"` (the base mount; entities live at `<base>/entities`) |
| `callerNotAuthorizedAsProvider` on a manual transfer start | provider already auto-started the transfer | use the consumer-client `query-data` path (`D1`); the manual two-step start is incompatible with `DPI_NODE_DATASPACE_AUTO_START_TRANSFERS="true"` |
| `query-data` hangs / times out | provider auto-start could not mint the transfer-start VC (the offer was provisioned under an identity the provider no longer controls) | the offer assigner must match the provider's current node identity; the provider mints the start VC with its own vault key. Re-run `register-dataset.sh` (it resolves the provider's current `nodeOrganizationId` and uses a `twin:jsonPath` target), then retry |
| `factory.noGet` on catalogue query | a `FilterBy...` filter with no handler registered | use an empty `filter: []` (`C1`) |
