#!/bin/bash

server1=$1
server2=$2
server3=$3

SERVERS="$1 $2 $3"

rsync -a shared/ ubuntu@$server1:/ops/shared/

if [ -e cluster-keys.json ]; then
  echo 'Vault Initialized; skipping'
else
  ssh -tt ubuntu@$server1 "bash -ic 'vault operator init -key-shares=1 -key-threshold=1 -format=json'" > cluster-keys.json

  export UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
  export ROOT_TOKEN=$(cat cluster-keys.json | jq -r ".root_token")

  for H in $SERVERS; do
    echo "$H";
    ssh -tt ubuntu@$H "bash -ic 'vault operator unseal $UNSEAL_KEY'";
  done

  ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault secrets enable -path=secret kv-v2'"
  ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/db/config user=poc pass=pocAZSXDCFVGB name=poc host=postgres.service.consul'"
fi

export UNSEAL_KEY=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
export ROOT_TOKEN=$(cat cluster-keys.json | jq -r ".root_token")

ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault policy write nomad-server /ops/shared/config/nomad-server-policy.hcl'"
ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault write /auth/token/roles/nomad-cluster @/ops/shared/config/nomad-cluster-role.json'"
ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault policy write db /ops/shared/config/db-policy.hcl'"
ssh -tt ubuntu@$server1 "bash -ic 'VAULT_TOKEN=$ROOT_TOKEN vault token create -policy nomad-server -period 72h -orphan -renewable=true -format=json'" > nomad_token.json

export NOMAD_VAULT_TOKEN=$(cat nomad_token.json | jq -r ".auth.client_token")

# Nomad will not start until token is in place
for H in $SERVERS; do
  echo "$H";
  ssh ubuntu@$H "sudo mkdir -p /secrets/; echo 'VAULT_TOKEN=$NOMAD_VAULT_TOKEN' | sudo tee /secrets/nomad-server-token"
done

echo
echo "Vault root token: $ROOT_TOKEN"
