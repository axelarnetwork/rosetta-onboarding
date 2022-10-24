# rosetta-onboarding
## Run a testnet node
1. setup config file
```
./scripts/setup.sh  -n testnet
```
2. Download snapshot data

Assume `AXELARD_HOME="$HOME/.axelar_testnet"`
```
cd $AXELARD_HOME
wget https://axelar-snapshot-rosetta.s3.us-east-2.amazonaws.com/axelar-testnet.tar.lz4
lz4 -dc --no-sparse axelar-testnet.tar.lz4 | tar xf -
```
3. Run docker image
```
cd $HOME/rpsetta-onboarding
export KEYRING_PASSWORD=[password]
./scripts/docker.sh -n testnet -a haiyizxx/axelar-core:v0.26.3-ubuntu
```

-----
Rosetta server runs on port 8080

The rosetta implementation is not backwards compatible prior to v0.21, due to some breaking changes , so I have `start_index": 3429625` in the config file.