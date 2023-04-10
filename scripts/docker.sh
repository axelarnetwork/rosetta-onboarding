#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

# shellcheck disable=SC1091
. "${script_dir}/utils.sh"


usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]
Set up the appropriate configs and download binaries to run an axelard node
Available options:
-h, --help                    Print this help and exit
-v, --verbose                 Print script debug info
-a, --axelar-core-image       Image of axelar core to checkout
-d, --root-directory          Directory for data.
-n, --network                 Network to join [mainnet|testnet]
EOF
    exit
}

parse_params() {
    # default values of variables set from params
    axelar_core_image=""
    root_directory=''
    git_root="$(git rev-parse --show-toplevel)"
    network=""
    chain_id=''
    docker_network='axelarate_default'
    axelar_mnemonic_path='unset'
    tendermint_key_path='unset'
    node_moniker='node'

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        --no-color) NO_COLOR=1 ;;
        -r | --reset-chain) reset_chain=1 ;;
        -a | --axelar-core-image)
            axelar_core_image="${2-}"
            shift
            ;;
        -d | --root-directory)
            root_directory="${2-}"
            shift
            ;;
        -n | --network)
            network="${2-}"
            shift
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # Set the appropriate chain_id
    if [ "$network" == "mainnet" ]; then
        if [ -z "${chain_id}" ]; then
            chain_id=axelar-dojo-1
        fi
        if [ -z "${root_directory}" ]; then
            root_directory="$HOME/.axelar"
        fi
    elif [ "$network" == "testnet" ]; then
        if [ -z "${chain_id}" ]; then
            chain_id=axelar-testnet-lisbon-3
        fi
        if [ -z "${root_directory}" ]; then
            root_directory="$HOME/.axelar_testnet"
        fi
    else
        msg "Invalid network provided: '${network}'"
        die "Use -n flag to provide an appropriate network"
    fi

    # check required params and arguments
    [[ -z "${axelar_core_image-}" ]] && die "Missing required parameter: axelar-core-image"
    [[ -z "${root_directory-}" ]] && die "Missing required parameter: root-directory"
    [[ -z "${network-}" ]] && die "Missing required parameter: network"

    logs_directory="$root_directory/logs"
    config_directory="$root_directory/config"

    return 0
}

check_environment() {
    msg "environment docker functions imported"
    local node_up
    node_up="$(docker ps --format '{{.Names}}' | (grep -w 'axelar-core' || true))"
    if [ -n "${node_up}" ]; then
        msg "FAILED: Node is already running. Terminate current container with 'docker stop axelar-core' and try again"
        exit 1
    fi

    if [ -n "$(docker container ls --filter name=axelar-core -a -q)" ]; then
        msg "Existing axelar-core container found."
        msg "Either DELETE the existing container with 'docker rm axelar-core' and rerun the script to recreate another container with the updated scripts and the existing chain data"
        msg "(the above will delete any container data in non-mounted folders)"
        msg "OR if you simply want to restart the container, do 'docker start axelar-core'"
        exit 1
    fi

    if [[ -z "$KEYRING_PASSWORD" ]]; then msg "FAILED: env var KEYRING_PASSWORD missing"; exit 1; fi

    if [[ "${#KEYRING_PASSWORD}" -lt 8 ]]; then msg "FAILED: KEYRING_PASSWORD must have length at least 8"; exit 1; fi
}

docker_mnemonic_path=""
docker_tendermint_key=""

prepare() {
    msg "preparing for docker deployment. ensure network $docker_network"
    local network_present
    network_present="$(docker network ls --format '{{.Name}}' | { grep "$docker_network" || :; })"
    if [ -z "$network_present" ]; then
        msg "creating docker network $docker_network"
        docker network create "$docker_network" --driver=bridge --scope=local
    else
        msg "docker network $docker_network already exists"
    fi

    if [[ "${axelar_mnemonic_path}" != 'unset' ]] && [[ -f "$axelar_mnemonic_path" ]]; then
        msg "copying validator mnemonic"
        cp "${axelar_mnemonic_path}" "${shared_directory}/validator.txt"
        docker_mnemonic_path="/home/axelard/shared/validator.txt"
    else
        msg "no mnemonic to recover"
    fi

    if [[ "${tendermint_key_path}" != 'unset' ]] && [[ -f "${tendermint_key_path}" ]]; then
        cp -f "${tendermint_key_path}" "${shared_directory}/tendermint.json"
        docker_tendermint_key="/home/axelard/shared/tendermint.json"
    fi
}

run_node() {
    if [ -n "$(docker container ls --filter name=axelar-core -a -q)" ]; then
        echo "Updating existing axelar-core container"
        docker rm axelar-core
    fi

    msg "running node"
    docker run                                                      \
      -d                                                            \
      --name axelar-core                                            \
      --network "$docker_network"                                   \
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
      --env NODE_MONIKER="${node_moniker}"                          \
      --env KEYRING_PASSWORD="${KEYRING_PASSWORD}"                  \
      --env AXELAR_MNEMONIC_PATH="${docker_mnemonic_path}"          \
      --env AXELARD_CHAIN_ID="${chain_id}"                          \
      --env TENDERMINT_KEY_PATH="${docker_tendermint_key}"          \
      -v "${root_directory}/:/home/axelard/.axelar"                     \
      "${axelar_core_image}" startNodeProc
    echo "wait 5 seconds for axelar-core to start..."
    sleep 5
}

post_run_message() {
    msg "To follow execution, run 'docker logs -f axelar-core'"
    msg "To stop the node, run 'docker stop axelar-core'"
    msg
    msg "SUCCESS"
    msg
    msg "CHECK the logs to verify that the container is running as expected"
    msg
    msg "BACKUP but do NOT DELETE the Tendermint consensus key (this is needed on node restarts):"
    msg "Tendermint consensus key: ${root_directory}/config/priv_validator_key.json"

    if [ -n "$docker_tendermint_key" ]; then
        rm -f "${shared_directory}/tendermint.json"
    fi
}

parse_params "$@"
setup_colors

check_environment

prepare

run_node

post_run_message
