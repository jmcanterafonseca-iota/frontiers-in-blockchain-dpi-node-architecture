# Scripts 

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
