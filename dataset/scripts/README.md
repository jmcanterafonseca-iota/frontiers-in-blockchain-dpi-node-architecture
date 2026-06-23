# Scripts

> Created: 2026-06-19
> Last updated: 2026-06-23

## End-to-end flow

`run-flow.sh` runs the whole 2-node dataspace flow against a running stack: provider provisioning (ODRL offer + dataset), consumer negotiation (`POST /consumer-client/negotiate`), then transfer + pull in a single consumer-client call (`POST /consumer-client/query-data`). The provider runs `DPI_NODE_DATASPACE_AUTO_START_TRANSFERS="true"`, so `query-data` drives request, provider auto-start, start callback, and consumer pull in one step.

```sh
./dataset/scripts/run-flow.sh
```

The consumer is reached at `http://localhost:3026` by default (`CONSUMER_HOST`); the provider at `http://localhost:3010` (`PROVIDER_HOST`). If `query-data` times out, retry: the provider's auto-start mints a verifiable credential on IOTA testnet, which is occasionally flaky.

## Creating consignments

Submits all three consignments in the `consignments/` folder to the AIG service and prints the AIG id of each one created.

```sh
./scripts/create-all-consignments.sh <email> <password>
```

## Retrieving an AIG

Fetches the changesets of an AIG and prints the notarization id and verification method for each version, with links to the IOTA explorer.

```sh
./scripts/get-aig.sh <email> <password> <aig-id>
```

## Registering a dataset


## Querying the details of a dataset


## Perform a negotiation

## Retrieve data

