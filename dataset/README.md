# Dataset

## Content

* `consignments` folder contains three sample Consignments.
* `participants` folder contains the identities of the provider and consumer participants.
* `scripts` folder contains scripts to perform operations.
* `postman` folder contains postman collections.

## Dataset Recipes

### Creating mnemonics for node and organization

```sh
npx "@twin.org/identity-cli@next" mnemonic --env wallet.env
```

```sh
npx "@twin.org/identity-cli@next" address --load-env wallet-org.env.provider --seed $SEED --count 2 --env wallet-org.env.provider --merge-env
```

### Resolving identities on the IOTA testnet

```sh
 npx "@twin.org/identity-cli@next" identity-resolve --did="did:iota:testnet:0x6b0ae4a48777a668376d992553c2fd0f58489179df0a34fa2fe91a759d2cc6d8" --node="https://api.testnet.iota.cafe" --network="TESTNET" --explorer="https://explorer.iota.org/"
```

### Adding verification method

```sh
./node-admin.sh consumer identity-verification-method-create --identity="did:iota:testnet:0x6b0ae4a48777a668376d992553c2fd0f58489179df0a34fa2fe91a759d2cc6d8" --verification-method-id="trust-assertion"
```

### Create VC as JWT for Dataspace authentication

```sh
./node-admin.sh consumer identity-verifiable-credential-create --subject-json=data/participants/consumer.json --identity="did:iota:testnet:0x6b0ae4a48777a668376d992553c2fd0f58489179df0a34fa2fe91a759d2cc6d8" --verification-method-id="trust-assertion"
```
