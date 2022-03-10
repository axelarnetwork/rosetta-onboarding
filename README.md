# rosetta-onboarding
## Run a testnet node
1. Download config and snapshot data
```
wget https://axelar-snapshot-rosetta.s3.us-east-2.amazonaws.com/axelar-testnet-lisbon-3.tar.gz
```
2. Unzip `axelar-testnet-lisbon-3.tar.gz` in $HOME directory
```
tar -xvf axelar-testnet-lisbon-3.tar.gz
```
3. Run docker image
```
docker run -d --name axelar-core -p 26656-26658:26656-26658 -p 8080:8080 --user 0:0 --restart unless-stopped \
--env HOME=/home/axelard --env START_REST=true -v "$HOME/.axelar/:/home/axelard/.axelar" \
haiyizxx/axelar-core:v0.15.0-rosetta
```
-----
- Rosetta server runs on port 8080
- The testnet genesis block height does not start from 1, so I have `start_index": 690490` in the config file to bootstrap data check