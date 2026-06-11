# frontiers-in-blockchain-dpi-node-architecture

Repo with datasets and materials to run an experiment using the DPI Nodes described by the Frontiers in Blockchain paper

## What's included

* A [Docker compose](./docker-compose.yaml) that allows to instantiate two DPI Nodes: serving a Data Provider actor and a Data Consumer actor.

* [Environment files](./environment/) for both the Consumer's and Provider's Nodes.

The infrastructure services used are:

* MySQL Database used to persist participant's data and also as an unsecure Vault. (In a real production environment this should be done through Hashicorp Vault or similar KMS).

* [IOTA testnet](https://explorer.iota.org/?network=testnet), the verifiable registry that holds identities, proofs, etc.

* [Apps](./apps/) In this folder two apps are included. A Dataspace App for handling data and a "Consumer Client" app that allows to negotiate and retrieve data. The former is executed on the Provider's Node and the latter on the Consumer's Node.

* In the [dataset](./dataset/) folder there is sample Consignment data, Postman collections and sample participant's identities.

* A `node-admin.sh` script utility that allows to administer both nodes.

## Getting started

The following steps must be conducted:

1. Ensure new mnemonics are created for the consumer's and provider's node, organization and admin user. See [examples](./environment/consumer/).

2. Ensure the address #0 of each mnemonic has funds. You can obtain them through the [IOTA testnet faucet](https://faucet.testnet.iota.cafe/).

3. Configure the mnemonic in the corresponding [bootstrap environment file](./environment/consumer/.env.bootstrap.consumer).

4. Bootstrap both nodes. In this step new organization and node identities are obtained and registered on the IOTA Ledger and their associated keys are stored on the IOTA Ledger. A new admin user is automatically generated that can be used to login into the Node and perform operations.

```sh
twin-node provider bootstrap
twin-node consumer bootstrap
```

*Note: Probably the addresses already supplied in this repository can be reused as they will still have funds and you can skip steps 1 to 3.*

After bootstrap has been perform provider and consumer as organizations will have their own IOTA Identity. You can see an [example](./dataset/participants/consumer.json).

1. Launch both nodes and the database.

```sh
docker compose up -d
```

Provider's Node will listen to port `3010` and Consumer's Node to port `3020`. The database will listen to port `` and each Node will have its own database.

## Scenario

To reproduce the scenario there is a postman collection. The steps to be taken are:

1. Register 3 consignments in the auditable item graph component. You can observe the proofs that are registered onchain through this request.

2. Register the DS App on the Provider's Node

3. REgister the offered dataset that will allow the data consumer to request a negotiation for consignments

4. Negotiate as a Consumer

5. Start a data transfer as a consumer

6. Retrieve the data
