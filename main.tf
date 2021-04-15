terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    nomad = {
      source = "hashicorp/nomad"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "nomad" {
  address = "http://${module.hashistack.server_lb_ip}:4646"
}

module "hashistack" {
  source = "./modules/hashistack"

  name                   = var.name
  region                 = var.region
  ami                    = var.ami
  server_instance_type   = var.server_instance_type
  client_instance_type   = var.client_instance_type
  key_name               = var.key_name
  server_count           = var.server_count
  client_count           = var.client_count
  retry_join             = var.retry_join
  nomad_binary           = var.nomad_binary
  root_block_device_size = var.root_block_device_size
  whitelist_ip           = var.whitelist_ip
}

resource "time_sleep" "wait_for_load_balancer" {
  create_duration = "2m"
  depends_on      = [module.hashistack.server_lb_ip]
}

resource "nomad_job" "fabio" {
  jobspec    = file("${path.module}/fabio.nomad")
  depends_on = [time_sleep.wait_for_load_balancer]
}

resource "nomad_job" "ebs_controller" {
  jobspec    = file("${path.module}/plugin-ebs-controller.nomad")
  depends_on = [time_sleep.wait_for_load_balancer]
}

resource "nomad_job" "ebs_node" {
  jobspec    = file("${path.module}/plugin-ebs-nodes.nomad")
  depends_on = [nomad_job.ebs_controller]
}

data "nomad_plugin" "ebs" {
  plugin_id        = "aws-ebs0"
  wait_for_healthy = true
  depends_on       = [nomad_job.ebs_node]
}

resource "nomad_volume" "postgres_volume" {
  depends_on      = [data.nomad_plugin.ebs]
  type            = "csi"
  plugin_id       = "aws-ebs0"
  volume_id       = "postgres"
  name            = "postgres"
  external_id     = module.hashistack.pg_volume_id
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"

  mount_options {
    fs_type = "ext4"
  }
}

resource "nomad_job" "postgresql" {
  jobspec    = file("${path.module}/postgresql.nomad")
  depends_on = [nomad_volume.postgres_volume]
}

resource "nomad_job" "api_sample_python" {
  jobspec    = file("${path.module}/api-sample-python.nomad")
  depends_on = [nomad_job.postgresql]
}

resource "null_resource" "clean_secrets" {
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f cluster-keys.json nomad_token.json"
  }
}
