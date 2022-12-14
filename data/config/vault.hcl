storage "raft" {
  address = "127.0.0.1:8200"
  path    = "vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

log_level = "debug"
ui = true
disable_mlock = true
api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://127.0.0.1:8201"
