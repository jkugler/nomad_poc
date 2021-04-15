job "http-echo" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"

  update {
    stagger      = "30s"
    max_parallel = 2
  }

  group "echo" {
    count = 3

    network {
      port "http" {}
    }
    
    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:latest"
        args = [ "-text", "Hello Dominent Hedge", "-listen", ":${NOMAD_PORT_http}" ]
        ports = ["http"]
      }

      service {
        name = "http-echo"
        port = "http"

        tags = [
          "jkugler",
          "urlprefix-/http-echo",
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "2s"
          timeout  = "2s"
        }
      }
    }
  }
}
