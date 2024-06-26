terraform {
  required_version = ">= 1.4.0"
}

variable "pool" {
  description = "Slurm pool of compute nodes"
  default = []
}

module "openstack" {
  #source         = "git::https://github.com/ComputeCanada/magic_castle.git//openstack"
  source         = "git::https://github.com/ComputeCanada/magic_castle.git//openstack?ref=13.3.2"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "13.3.2"

  cluster_name = "cs-ml"
  domain       = "ace-net.training"
  image        = "Rocky-8.10-x64-2024-06"

  instances = {
    mgmt   = { image="Rocky-9.1-x64-2023-02",type = "p8-12gb", tags = ["puppet", "mgmt", "nfs"],disk_size=50, count = 1 }
    login  = { image="Rocky-9.1-x64-2023-02",type = "p8-12gb", tags = ["login", "public", "proxy"],disk_size=50, count = 1 }
    node   = { image="Rocky-8.10-x64-2024-06",type = "g1-8gb-c4-22gb", tags = ["node"], count = 1 }
    node2x  = { image="Rocky-8.10-x64-2024-06",type = "g1-16gb-c8-40gb", tags = ["node"], count = 0 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = {
    nfs = {
      home     = { size = 100 }
      project  = { size = 50 }
      scratch  = { size = 50 }
    }
  }

  public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILWHSMDMhlXIy+C7/Dw4b7dUgfZkE3AXnG8PDDkyY9Qm cgeroux@lunar"]
  generate_ssh_key=true

  nb_users = 100
  # Shared password, randomly chosen if blank
  guest_passwd = ""
}

output "accounts" {
  value = module.openstack.accounts
}

output "public_ip" {
  value = module.openstack.public_ip
}

# Uncomment to register your domain name with CloudFlare
module "dns" {
  source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/cloudflare"
  name             = module.openstack.cluster_name
  domain           = module.openstack.domain
  bastions         = module.openstack.bastions
  public_instances = module.openstack.public_instances
  ssh_private_key  = module.openstack.ssh_private_key
  sudoer_username  = module.openstack.accounts.sudoer.username
}

## Uncomment to register your domain name with Google Cloud
# module "dns" {
#   source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/gcloud"
#   project          = "your-project-id"
#   zone_name        = "you-zone-name"
#   name             = module.openstack.cluster_name
#   domain           = module.openstack.domain
#   bastions         = module.openstack.bastions
#   public_instances = module.openstack.public_instances
#   ssh_private_key  = module.openstack.ssh_private_key
#   sudoer_username  = module.openstack.accounts.sudoer.username
# }

output "hostnames" {
  value = module.dns.hostnames
}
