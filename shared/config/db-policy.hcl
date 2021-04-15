path "secret/*" {
  capabilities = ["list"]
}

path "secret/data/db/config" {
  capabilities = ["list", "read"]
}
