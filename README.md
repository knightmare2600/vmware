#VMWare Tools and Scripts
##About
This repo contains scripts and tools for working with VMWare ESX 5.x and 6.x it is used by me to script creation of VMWare machines on an ESX host using puppet and SSH keys.

##Usage
Copy the `create.sh` script to a persistent location on your ESX host. I've found `/vmfs/volumes` is a good start. Then run the script for help.

Examples:

```  Script for automatic Virtual Machine creation for ESX
  Usage: ./create.sh options: -n -l -d <|-c|-i|-r|-s|-e|-g|-h>
  -n: Name of VM (required)
  -l: VM Network to connect (required)
  -d: datastore (required - case sensitive)
  -c: Number of virtual CPUs
  -i: location of an ISO image (optional)
  -r: RAM size in MB
  -s: Disk size in GB
  -e: Ethernet Type [e1000 | vmxnet | vlance]
  -g: GuestOS [ win7 | 2008r2 | win8 | 2012r2 | ubuntu | esx5 | esx6 ]
  -h: This help screen

  Default values are: 1 CPU, 512MB RAM, 10GB HDD, e1000 Adapter on Ubuntu Guest

  e.g. create.sh -n TestVM -l 'VM Network' -d Singledisk_1 -c 1 -r 1024 -s 10 -e vmxnet```

The script will automatically upgrade the hardware to a version compatible with the Guest OS.

##Notes
This code has been tested on VMWare ESX 5.5 and ESX 6.0. Due to limitations in the ash shell of ESX, some of the code is not as clean as it could be. However, it is documented and is fairly clean.

Licensed under GPLv3.

##Resources
https://github.com/tamaspiros/auto-create
http://www.virtuallyghetto.com/2013/10/quick-tip-using-cli-to-upgrade-to.html

##Authors
Created by Tamas Piros and upgraded by knightmare2600
