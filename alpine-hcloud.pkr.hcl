packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/hcloud"
    }
  }
}

variable "hcloud_token" {
  type    = string
  default = env("HCLOUD_TOKEN")
}

variable "alpine_branch" {
    type = string
}

source "hcloud" "alpine" {
  image           = "debian-11"
  location        = "nbg1"
  server_type     = "cx11"
  snapshot_name   = "alpine-${var.alpine_branch}"
  ssh_keys        = ["default"]
  ssh_username    = "root"
  rescue          = "linux64"
  token           = var.hcloud_token
  snapshot_labels = { os = "alpine", release = "${var.alpine_branch}" }
}

build {
  sources = ["source.hcloud.alpine"]

  provisioner "file" {
    source      = "alpine-setup.sh"
    destination = "/tmp/alpine-setup.sh"
  }

  provisioner "shell" {
    inline = [
      "set -x",
      "curl -sL https://raw.githubusercontent.com/alpinelinux/alpine-make-vm-image/master/alpine-make-vm-image -o /tmp/alpine-make-vm-image",
      "chmod +x /tmp/alpine-make-vm-image",
      "chmod +x /tmp/alpine-setup.sh",
      "/tmp/alpine-make-vm-image --packages 'openssh e2fsprogs-extra curl bind-tools jq htop nano' --branch ${var.alpine_branch} --image-format qcow2 --script-chroot /tmp/alpine-${var.alpine_branch}.qcow2 -- /tmp/alpine-setup.sh",
      "qemu-img convert -f qcow2 -O raw /tmp/alpine-${var.alpine_branch}.qcow2 /dev/sda"
    ]
  }
}