#!/bin/sh

############################################################################
#                                                                          #
# Created 16 May 2015 Tamas Piros     Initial pull from github             #
# Updated 11 Oct 2015 robertmc        Use VMWare script as basis for Xen   #
#                                                                          #
############################################################################

#-----------------: A WORD ON OS SUPPORT IN THE VMX FILE :-----------------#
#                                                                          #
# There's a text file containing all the OS options included in this repo, #
# but you can run xe template-list too.  I'm using only OS editions I use  #
# (2008R2, 2012, Win7, Win8, Ubuntu, RHEL & ESX). Feel free to update      #
# yours, but the logic code would be a nightmare!                          #
#--------------------------------------------------------------------------#

# TODO: Add option to print out ethernet MAC address for those who PXE boot
# TODO: Maybe allow different NIC type for each adapter
## TODO: FIX Currently the boot order is not working, and only PXE boots by default

## paratmers:
## machine name (required)
## VM Network to attach NIC to
## Datastore to use (required)
## CPU (number of cores)
## RAM (memory size in MB)
## HDD Disk size (in GB)
## ISO (Location of ISO image, optional)
## Type of NIC to use (optional)
## Guest OS type (optional)
## Number of NICs (optional)

## Default parameters:
## 1 CPU, 512MB RAM, 10GB HDD, 1 x e1000 NIC, ISO: 'blank', GuestOS: Ubuntu 64 Bit


##    so VM based on Debian Wheezy 7.0 (32-bit) template, VM name is newVM
##   change boot order boot from VM hard disk:
##  boot on floppy (a), hard disk (c), Network (n) or CD-ROM (d)
# default: hard disk, cd-rom, floppy
##boot="ncd"

##    xe vbd-list vm-uuid=[VM uuid] userdevice=0
##    xe vbd-param-set uuid=[device UUID] bootable=false

##    Choose boot disk for VM (in ths case . Debian install image from NFS):
#   xe cd-list
#    xe vm-cd-add vm="newVM" cd-name="debian-7.0.0-i386-netinst.iso" device=3
#    xe vbd-list vm-name-label="newVM" userdevice=3
#    xe vbd-param-set  uuid=[device uuid] bootable=true
#    xe vm-param-set uuid=[VM uuid] other-config:install-repository=cdrom


phelp() {
	echo "  Script for automatic Virtual Machine creation for XenServer"
	echo "  Usage: `basename $0` options: -n -l -d <|-c|-i|-r|-s|-e|-g|-a|-v|-h>"
	echo "  -n: Name of VM (required)"
	echo "  -l: VM Network to connect (required)"
	echo "  -d: datastore (required - case sensitive)"
	echo "  -c: Number of virtual CPUs"
	echo "  -i: location of an ISO image (optional)"
	echo "  -r: RAM size in MB"
	echo "  -s: Disk size in GB"
	echo "  -e: Number of Ethernet adapters [max: 9]"
	echo "  -g: GuestOS [ win7 | 2008r2 | win8 | 2012r2 | ubuntu | esx5 | esx6 ]"
	echo "  -a: SCSI Adapter type [ buslogic | lsilogic| lsisas1068 ]"
	echo "  -v: Virtual Ethernet card type [e1000 | vmxnet | vlance]"
	echo "  -h: This help screen"
	echo
	echo "  Default values are: 1 CPU, 512MB RAM, 10GB HDD, 1 x e1000 NIC, LSI SAS SCSI on an Ubuntu Guest"
	echo
	echo "  e.g. create.sh -n TestVM -l 'VM Network' -d Singledisk_1 -c 1 -r 1024 -s 10 -e 2 -v vmxnet"
	echo
}

## Setting up some of the default variables
CPU=1
RAM=512
SIZE=10
ISO=""
FLAG=true
ERR=false
NICTYPE=e1000
GUESTOS='Ubuntu Trusty Tahr 14.04'
HWVER=08 ## Can be 08-11 Hey look... it goes up to 11!
SCSIADAPTER=lsisas1068
NUMNICS=1

## Error checking will take place as well
## the NAME has to be filled out (i.e. the $NAME variable needs to exist)
## The CPU must be an integer between 1 & 32. Modify the 'if' for more than 32 cores on a VM
## You need to assign more than 1 MB of ram, and of course RAM has to be an integer as well
## The HDD-size has to be an integer and has to be greater than 0.
## If the ISO parameter is added, we are checking for an actual .iso extension

while getopts :h:n:c:i:r:s:l:e:d:a:v:g: option
do
  case $option in
   n)
	NAME=${OPTARG};
	FLAG=false;
	if [ -z $NAME ]; then
	 ERR=true
	 MSG="$MSG | Please make sure to enter a VM name."
	fi
	;;
   c)
	CPU=${OPTARG}
	if [ `echo "$CPU" | egrep "^-?[0-9]+$"` ]; then
	  if [ "$CPU" -le "0" ] || [ "$CPU" -ge "32" ]; then
	    ERR=true
	    MSG="$MSG | The number of cores has to be between 1 and 32."
	  fi
	else
	  ERR=true
	  MSG="$MSG | The CPU core number has to be an integer."
	fi
	;;
   i)
	ISO=${OPTARG}
	if [ ! `echo "$ISO" | egrep "^.*\.(iso)$"` ]; then
	  ERR=true
	  MSG="$MSG | The extension should be .iso"
	fi
	;;
   r)
	RAM=${OPTARG}
	if [ `echo "$RAM" | egrep "^-?[0-9]+$"` ]; then
	  if [ "$RAM" -le "0" ]; then
	    ERR=true
	    MSG="$MSG | Please assign more than 1MB memory to the VM."
	  fi
	else
	  ERR=true
	  MSG="$MSG | The RAM size has to be an integer."
	fi
	;;
   s)
	SIZE=${OPTARG}
	if [ `echo "$SIZE" | egrep "^-?[0-9]+$"` ]; then
	  if [ "$SIZE" -le "0" ]; then
	    ERR=true
	    MSG="$MSG | Please assign more than 1GB for the HDD size."
	  fi
	else
	  ERR=true
	  MSG="$MSG | The HDD size has to be an integer."
	fi
	;;

   e)
	NUMNICS=${OPTARG}
	if [ `echo "$NUMNICS" | egrep "^-?[0-9]+$"` ]; then
	  if [ "$NUMNICS" -eq "1" ]; then
	    ERR=true
	    MSG="$MSG Don't be silly! If you want a single NIC, don't specify the -e parameter."
	  fi
	else
	  ERR=true
	  MSG="$MSG | Please enter a number of NICs between 2 and 9."
	fi
	;;

   v)
	## Logic code goes here for Ethernet type: e1000, vmxnet, vlance
	NICTYPE=${OPTARG}
	FLAG=false;
	if [ -z $NICTYPE ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid ethernet adapter type."
	fi
	;;
   l)
	VMNETWORK=${OPTARG}
	FLAG=false;
	if [ -z "$VMNETWORK" ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid VM Network name."
	fi
	;;
   a)
	SCSIADAPTER=${OPTARG}
	FLAG=false;
	if [ -z '$SCSIADAPTER' ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid SCSI Bus Adapter"
	fi
	;;

   g)
	GUESTOS=${OPTARG}
	FLAG=false;
	if [ -z '$GUESTOS' ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid Guest OS name."
	elif [ "$GUESTOS" == "win7" ]; then
	  GUESTOS='Windows 7 (64-bit)'
          FLAG=false
	elif [ "$GUESTOS" == "2008r2" ]; then
	  GUESTOS='Windows Server 2008 R2 (64-bit)'
          FLAG=false
	elif [ "$GUESTOS" == "win8" ]; then
	  GUESTOS='Windows 8 (64-bit)'
          FLAG=false
	  HWVER=09
	elif [ "$GUESTOS" == "2012r2" ]; then
	  GUESTOS='Windows Server 2012 R2 (64-bit)'
          FLAG=false
	  HWVER=09
	elif [ "$GUESTOS" == "ubuntu" ]; then
	  GUESTOS='Ubuntu Trusty Tahr 14.04'
          FLAG=false
### You can't nest ESX inside XenServer without hacking around so this is unsupported
### Tech: Xenserver emulates RTL8139 which *can* be injected, but again, unsupported
##	elif [ "$GUESTOS" == "esx5" ]; then
##          GUESTOS=vmkernel5Guest
##          FLAG=false
##	elif [ "$GUESTOS" == "esx6" ]; then
##          GUESTOS=vmkernel6Guest
##          FLAG=false
	## copy the 3 lines above to add in more guest support as needed
	else
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid Guest OS name."
        fi
	;;

   d)
	DATASTORE=${OPTARG}
	FLAG=false;
	if [ -z "$DATASTORE" ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid case sensitive datastore name."
	elif [ ! -d "/vmfs/volumes/$DATASTORE" ]; then
	  DATASTORES=`ls -l /vmfs/volumes/ | grep ^l | awk '{ print $9 }'`
	  ERR=true
	  MSG="Datastore not found in /vmfs/volumes/ Please check the case sensitive name. Valid datastores are: $DATASTORES"
	fi
	;;

   h)
	phelp; exit 1;;
 
   \?) echo "Unknown option: -$OPTARG" >&2; phelp; exit 1;;
        :) echo "Missing option argument for -$OPTARG" >&2; phelp; exit 1;;
        *) echo "Unimplimented option: -$OPTARG" >&2; phelp; exit 1;;
        esac
done

if $FLAG; then
  echo "You need to at least specify the name of the machine with the -n parameter."
  exit 1
fi

if $ERR; then
  echo $MSG
  exit 1
fi

# Xen creates an LV rather than folder with VM in it.
#if [ -d "/vmfs/volumes/$DATASTORE/$NAME" ]; then
#  echo "Directory - ${NAME} already exists, can't recreate it."
#  exit
#fi

### Here, we start creating the VM ###
## After selecting template, create VM, Xen works by creating the VM and adding
## hardware to it. Make this a variable as we use UUID later to add stuff to VM
UUID=`xe vm-install template="${GUESTOS}" new-name-label="${NAME}"`
echo "$UUID"

## Creating the folder for the Virtual Machine
#mkdir /vmfs/volumes/${DATASTORE}/${NAME}

## Bump the disk size. To check: xe vm-disk-list vm="newVM"
DISKUUID=`xe vm-disk-list vm="${NAME}" | egrep '(VDI|uuid)' | tail -n1 | awk '{ print $NF }'`
echo "${SIZE}"
xe vdi-resize uuid="${DISKUUID}" disk-size="${SIZE}"GiB

## Bump the RAM size to requested size
## Check it out with: xe vm-list name-label="newVM" params=all | grep memory
## This needs to be based on template list
xe vm-memory-limits-set dynamic-max=${RAM}MiB dynamic-min=${RAM}MiB static-max=${RAM}MiB static-min=${RAM}MiB name-label="${NAME}"


## Add the requested number of NICs to the VM. i'm not letting you add more
## than nine because that's just silly. You can change it of course. If you
## wonder why I didn't use vim-cmd vmsvc/devices.createnic it's because the
## syntax didn't work for me even with unit ID 8 - 4096.

## VMICs start from 0 so start at 1 to compliment the logic above which does
## not allow user to specify less than 2 NICs 
NIC=1

## TODO: Re-instate number of NICs so this loop needs some work
###while [[ "$NIC" -lt "$NUMNICS" ]] ; do
###echo "$NIC"
###echo "$NIC"
### Update the VMX file. This is why I put the NICs last
###exit 0
#
#cat << EOF >> /vmfs/volumes/${DATASTORE}/$NAME/$NAME.vmx
#ethernet${NIC}.present = "TRUE"
#ethernet${NIC}.virtualDev = "${NICTYPE}"
#ethernet${NIC}.networkName = "${VMNETWORK}"
#ethernet${NIC}.generatedAddressOffset = "0"
#EOF

## Get network interface list on host: xe network-list
## Generate a MAC using Xen's prefix for easy DHCP management
MAC=`hexchars="0123456789ABCDEF" ; end=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' ) ; echo 00:16:3e$end`

## Add physical network interface to VM:
## xe network-list we need to make this do logic check too, and not always use xenbr0

## This code is something else... If only Xenserver allowed you to print info only one
## virtual switch without all this!
NETUUID=` xe network-list | egrep '(uuid|bridge)' | sed 's/  //g' | sed 's/\<bridge\>//g' |  tr -d '\n( RO)' | sed 's/uuid:/\'$'\n/g' | grep ${VMNETWORK} | awk --field-separator=: '{ print $1 }' `
## Now we can add the NIC to the VM, with our UUID, MAC Address and Network UUID
xe vif-create vm-uuid=${UUID} network-uuid=${NETUUID} mac=${MAC} device=0

# Bump NIC by +1 and carry on
##NIC=`echo $(($NIC+1))`
##done

## Tweak boot order to be Network, HDD (C:) and Disk (D:)
xe vm-param-set HVM-boot-policy="ncd" uuid=${UUID}

## Powering up virtual machine:
xe vm-start vm=${NAME}

## For those without XenCentre console, one can connect to VM console using VNC
## retrieve VM domain number:
xe vm-param-list uuid=${UUID}| grep dom-id
##    retrieve VNC port for this domain:
xenstore-read /local/domain/${NAME}/console/vnc-port

## remote connection ([port] . last two digits from previous output):
#   vncviewer -via root@[xenserver] localhost:[port]

echo
echo "The Virtual Machine is now setup & the VM has been started up. Your have the following configuration:"
echo "Name......: ${NAME}"
echo "Datastore.: ${DATASTORE}"
echo "CPU:......: ${CPU}"
echo "RAM (MB)..: ${RAM}"
echo "HDD-size..: ${SIZE}"
echo "Network...: ${VMNETWORK}"
if [ -n "$ISO" ]; then
	echo "ISO: ${ISO}"
else
	echo "No ISO added."
fi
echo "Thank you."
echo
exit
