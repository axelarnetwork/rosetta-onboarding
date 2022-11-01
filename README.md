# rosetta-onboarding

## Build docker image
```
docker build --build-arg GIT_REF=[tag] -t axelar-core:[tag] -f Dockerfile .
```
e.g.
```
docker build --build-arg GIT_REF=v0.26.5 -t axelar-core:v0.26.5 -f Dockerfile .
```
## Run a testnet node
1. setup config file

- Script
```
cd $HOME/rosetta-onboarding
./scripts/setup.sh  -n testnet
```
- Manual
```
cd $HOME/rosetta-onboarding
mkdir $HOME/.axelar_testnet
mkdir $HOME/.axelar_testnet/config
cp ./configuration/config.toml $HOME/.axelar_testnet/config/config.toml
cp ./configuration/app.toml $HOME/.axelar_testnet/config/app.toml
```
2. Download snapshot data

```
cd $HOME/.axelar_testnet
wget https://axelar-snapshot-rosetta.s3.us-east-2.amazonaws.com/axelar-testnet.tar.lz4
lz4 -dc --no-sparse axelar-testnet.tar.lz4 | tar xf -
```
3. Run docker image
- script
```
cd $HOME/rpsetta-onboarding
export KEYRING_PASSWORD=[password]
./scripts/docker.sh -n testnet -a haiyizxx/axelar-core:v0.26.3-ubuntu
```
- manual
```
docker run                                                          \
      -d                                                            \
      --name axelar-core                                            \
      -p 1317:1317                                                  \
      -p 26656-26658:26656-26658                                    \
      -p 26660:26660                                                \
      -p 9090:9090                                                  \
      -p 8080:8080                                                  \
      --user 0:0                                                    \
      --restart unless-stopped                                      \
      --env HOME=/home/axelard                                      \
      --env START_REST=true                                         \
      --env CONFIG_PATH=/home/axelard/shared/                       \
      --env NODE_MONIKER=node                                       \
      --env KEYRING_PASSWORD="password"                             \
      --env AXELARD_CHAIN_ID="axelar-testnet-lisbon-3"              \
      -v "${HOME}/.axelar_testnet:/home/axelard/.axelar"            \
      axelar-core:v0.26.5 startNodeProc
```
-----

Rosetta server runs on port 8080

The rosetta implementation is not backwards compatible prior to v0.21, due to some breaking changes, so I have `start_index": 3429625` in the config file.