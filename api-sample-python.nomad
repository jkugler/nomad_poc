job "api-sample-python" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"

  update {
    stagger      = "30s"
    max_parallel = 2
  }

  group "api-sample" {
    count = 3

    network {
      port "http" {}
    }

    task "server" {
      driver = "docker"

      config {
        image = "jkugler/api-sample-python:20210504"
        args = [ ":${NOMAD_PORT_http}" ]
        ports = ["http"]
      }

      vault {
        policies = ["db"]
        change_mode   = "signal"
        change_signal = "SIGUSR1"
      }

      template {
        data = <<EOT
          {{ with secret "secret/data/db/config" }}
POSTGRES_USER="{{ .Data.data.user }}"
POSTGRES_PASSWORD="{{ .Data.data.pass | toJSON }}"
POSTGRES_HOST="{{ .Data.data.host }}"
POSTGRES_DB="{{ .Data.data.name }}"
          {{ end }}
EOT
        destination = "db.env"
        env         = true
      }

      service {
        name = "api-sample-python"
        port = "http"

        tags = [
          "jkugler",
          "urlprefix-/",
        ]

        check {
          type     = "http"
          path     = "/api"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
