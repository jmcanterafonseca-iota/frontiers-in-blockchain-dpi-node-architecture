# Scripts

> Created: 2026-06-19
> Last updated: 2026-06-24

Note: `email` and `password` are always optional parameters. 

## Provider: Creating consignments

Submits all three consignments in the `consignments/` folder to the AIG service and prints the AIG id of each one created.

```sh
./scripts/create-all-consignments.sh <email> <password>
```

## Provider: Retrieving an AIG

Fetches the changesets of an AIG and prints the notarization id and verification method for each version, with links to the IOTA explorer.

```sh
./scripts/get-aig.sh <aig-id> <email> <password>
```

## Provider: Listing all the AIGs

Lists all the AIGs present.

```sh
./scripts/list-aigs.sh <aig-id> <email> <password>
```

## Provider: Registering a dataset plus Offer Policy

Registers the dataset concerned.

```sh
./scripts/register-dataset.sh <email> <password>
```

## Provider: Querying the details of a dataset

Query the details fo the registered dataset.

```sh
./scripts/get-dataset-info.sh <email> <password>
```

## Consumer : Perform a negotiation

Performs a negotiation over a dataset.

```sh
./scripts/negotiate.sh <entityType> <email> <password>
```

## Retrieve data

Retrieves the data once a negotiation has concluded successfully.

```sh
./scripts/get-data.sh <negotiationId> <entityType> <entityId> <email> <password>
```
