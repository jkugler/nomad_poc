job "postgres" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres" {
    count = 1

    volume "postgres" {
      type      = "csi"
      read_only = false
      source    = "postgres"
    }

    network {
      port  "db"  {
        static = 5432
      }
    }

    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:13.2"
        ports = ["db"]
      }

    vault {
      policies = ["db"]
      change_mode   = "signal"
      change_signal = "SIGUSR1"
    }
      volume_mount {
        volume = "postgres"
        destination = "/var/lib/postgresql/data"
        read_only = false
      }

      template {
        data = <<EOT
          {{ with secret "secret/data/db/config" }}
POSTGRES_USER="{{ .Data.data.user }}"
POSTGRES_PASSWORD="{{ .Data.data.pass | toJSON }}"
PGDATA="/var/lib/postgresql/data/pgdata"
          {{ end }}
EOT
        destination = "db.env"
        env         = true
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 1000
        memory = 1024
      }
      service {
        name = "postgres"
        port = "db"

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

  }

  update {
    max_parallel = 1
    min_healthy_time = "5s"
    healthy_deadline = "3m"
    auto_revert = false
    canary = 0
  }
}
