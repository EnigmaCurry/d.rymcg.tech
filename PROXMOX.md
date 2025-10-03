# Docker on Proxmox (PVE) VM

[Proxmox Virtual Environment
(PVE)](https://www.proxmox.com/en/products/proxmox-virtual-environment/overview)
is a powerful, open-source, Virtual Machine hypervisor that you can
self-host on any AMD64 PC. PVE is a derriviative of Debian Linux and
has a nice web interface (and API) for the administration of several
virtual machines using the Linux Kernel Virtual Machine (KVM).

A KVM guest machine is a great place to install Docker. You can
install several machines on one host PC. Each virtual machine has it's
own network stack and execution environment. Virtualization lets you
control the life and death of your Docker servers as if looking into a
crystal ball. You can start, pause, stop, snapshot, clone, and backup
all of your machines from the PVE control plane.

## Install Proxmox

To install Proxmox, follow the blog series at
[blog.rymcg.tech](https://blog.rymcg.tech/tags/proxmox/).

For the purpose of setting up for Docker, you only need to follow
parts 1, 2, 3, and 5:

 * part 1: [Installation and Setup](https://blog.rymcg.tech/blog/proxmox/01-install/)
 * part 2: [Networking](https://blog.rymcg.tech/blog/proxmox/02-networking/)
 * part 3: [Notifications](https://blog.rymcg.tech/blog/proxmox/03-notifications/)
 * part 5: [KVM and Cloud-Init](https://blog.rymcg.tech/blog/proxmox/05-kvm-templates)

## Install Docker

By the time you finish part 5 of the blog, you should have a running
VM that you can SSH into. Follow the rest of the steps in
[DOCKER.md](DOCKER.md).


## Proxmox VE Documentation

Reference the [PVE documentation](https://pve.proxmox.com/pve-docs/)
for more information about administering your server.
