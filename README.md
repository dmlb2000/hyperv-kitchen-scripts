# Hyper-V Vagrant SSH

This repository is an attempt to try and get vagrant to transparently use
Hyper-V and with the Vagrant images. Then setup and configure Vagrant SSH for
use with Kitchen (hopefully).

We need to use vagrant managed servers plugin.

`vagrant plugin install vagrant-managed-servers`

The power shell scripts dump a global Vagrantfile and allow you to connect
to one virtual machine.
