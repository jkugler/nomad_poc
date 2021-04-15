vault {
  address = "https://active.vault.service.consul:8200"
  token=""
  grace = "1s"
  unwrap_token = false
  renew_token = true
  tls_skip_verify = true
}

syslog {
  enabled = true
  facility = "LOCAL5"
}
