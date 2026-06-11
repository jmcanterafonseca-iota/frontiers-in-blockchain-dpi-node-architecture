# Dataset

## Creating mnemonics for node and organization

```sh
npx "@twin.org/identity-cli@next" mnemonic --env wallet.env
```

```sh
npx "@twin.org/identity-cli@next" address --load-env wallet-org.env.provider --seed $SEED --count 2 --env wallet-org.env.provider --merge-env
```
