#!/bin/sh

############################################################################
#                                                                          #
# Created 16 May 2015 Tamas Piros     Initial pull from github             #
# Updated 17 May 2015 robertmc        Add option for VM Network & num NICS #
# Updated 17 May 2015 robertmc        Add option for datastore too         #
# Updated 23 May 2015 robertmc        Fix typo & make SCSI bus lsisas1068  #
# Updated 23 May 2015 robertmc        Add 50ms delay to BIOS for slow LANs #
# Updated 24 May 2015 robertmc        NIC type, fix error checking logic & #
#                                     tidy code indentation again          #
# Updated 06 Jun 2015 robertmc        Add guest OS parameter. But limit it #
#                                     due to sheer volume of options       #
# Updated 07 Jun 2015 robertmc        Bump HW version for W8 & 2012 VMs    #
#                                                                          #
############################################################################

#-----------------: A WORD ON OS SUPPORT IN THE VMX FILE :-----------------#
#                                                                          #
# There's a text file containing all the OS options included in this repo, #
# but you can run strings on /bin/hostd too.  I'm using only OS editions I #
# use (2008R2, 2012, Win7, Win8, Ubuntu, RHEL & ESX). Feel free to update  #
# yours, but the logic code would be a nightmare!                          #
#--------------------------------------------------------------------------#

# TODO: scsi0.virtualDev = "lsilogic|lsisas1068" can be a command line option

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

## Default parameters:
## 1 CPU, 512MB RAM, 10GB HDD, e1000 NIC, ISO: 'blank', GuestOS: Ubuntu 64 Bit

phelp() {
	echo "  Script for automatic Virtual Machine creation for ESX"
	echo "  Usage: ./create.sh options: -n -l -d <|-c|-i|-r|-s|-e|-g|-h>"
	echo "  -n: Name of VM (required)"
	echo "  -l: VM Network to connect (required)"
	echo "  -d: datastore (required - case sensitive)"
	echo "  -c: Number of virtual CPUs"
	echo "  -i: location of an ISO image (optional)"
	echo "  -r: RAM size in MB"
	echo "  -s: Disk size in GB"
	echo "  -e: Ethernet Type [e1000 | vmxnet | vlance]"
	echo "  -g: GuestOS [ win7 | 2008r2 | win8 | 2012r2 | ubuntu | esx5 | esx6 ]"
	echo "  -h: This help screen"
	echo
	echo "  Default values are: 1 CPU, 512MB RAM, 10GB HDD, e1000 Adapter on Ubuntu Guest"
	echo
	echo "  e.g. create.sh -n TestVM -l 'VM Network' -d Singledisk_1 -c 1 -r 1024 -s 10 -e vmxnet"
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
GUESTOS=ubuntu
HWVER=8

## Error checking will take place as well
## the NAME has to be filled out (i.e. the $NAME variable needs to exist)
## The CPU has to be an integer and it has to be between 1 and 32. Modify the if statement if you want to give more than 32 cores to your Virtual Machine, and also email me pls :)
## You need to assign more than 1 MB of ram, and of course RAM has to be an integer as well
## The HDD-size has to be an integer and has to be greater than 0.
## If the ISO parameter is added, we are checking for an actual .iso extension

while getopts n:c:i:r:s:l:e:d:g:h: option
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
	if [ -z '$VMNETWORK' ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid VM Network name."
	fi
	;;

   g)
	GUESTOS=${OPTARG}
	FLAG=false;
	if [ -z '$GUESTOS' ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid Guest OS name."
	elif [ "$GUESTOS" == "win7" ]; then
	  GUESTOS=windows7-64
          FLAG=false
	elif [ "$GUESTOS" == "2008r2" ]; then
	  GUESTOS=windows7srv-64
          FLAG=false
	elif [ "$GUESTOS" == "win8" ]; then
	  GUESTOS=windows8-64
          FLAG=false
	  HWVER=9
	elif [ "$GUESTOS" == "2012r2" ]; then
	  GUESTOS=windows8srv-64
          FLAG=false
	  HWVER=9
	elif [ "$GUESTOS" == "ubuntu" ]; then
	  GUESTOS=ubuntu64Guest
          FLAG=false
	elif [ "$GUESTOS" == "esx5" ]; then
	  GUESTOS=vmkernel5Guest
          FLAG=false
	elif [ "$GUESTOS" == "esx6" ]; then
	  GUESTOS=vmkernel6Guest
          FLAG=false
	## copy the 3 lines above to add in more guest support as needed
	else
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid Guest OS name."
        fi
	;;

   d)
	DATASTORE=${OPTARG}
	FLAG=false;
	if [ -z '$DATASTORE' ]; then
	  ERR=true
	  MSG="$MSG | Please make sure to enter a valid case sensitive datastore name."
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

if [ -d "$NAME" ]; then
	echo "Directory - ${NAME} already exists, can't recreate it."
	exit
fi

#Creating the folder for the Virtual Machine
mkdir /vmfs/volumes/${DATASTORE}/${NAME}

#Creating the actual Virtual Disk file (the HDD) with vmkfstools
vmkfstools -c "${SIZE}"G /vmfs/volumes/${DATASTORE}/$NAME/$NAME.vmdk

# Creating the config file
touch /vmfs/volumes/${DATASTORE}/$NAME/$NAME.vmx

#writing information into the configuration file
cat << EOF > /vmfs/volumes/${DATASTORE}/$NAME/$NAME.vmx

config.version = "9"
virtualHW.version = "7"
vmci0.present = "TRUE"
displayName = "${NAME}"
floppy0.present = "FALSE"
numvcpus = "${CPU}"
scsi0.present = "TRUE"
scsi0.sharedBus = "none"
scsi0.virtualDev = "lsisas1068"
memsize = "${RAM}"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "${NAME}.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"
ide1:0.present = "TRUE"
ide1:0.fileName = "${ISO}"
ide1:0.deviceType = "cdrom-image"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
ethernet0.pciSlotNumber = "32"
ethernet0.present = "TRUE"
ethernet0.virtualDev = "${NICTYPE}"
ethernet0.networkName = "${VMNETWORK}"
ethernet0.generatedAddressOffset = "0"
guestOS = "${GUESTOS}"
bios.bootDelay = "50"
EOF

## Adding Virtual Machine to VM register - modify your path accordingly!!
MYVM=`vim-cmd solo/registervm /vmfs/volumes/${DATASTORE}/${NAME}/${NAME}.vmx`

## Upgrade the hardware version, but stick with HW version 8 since 9+ expects
## the WebUI VSpehre client (urgh!) except if it's Win8 or 2012.
vim-cmd vmsvc/upgrade $MYVM vmx-0$HWVER

## Powering up virtual machine:
vim-cmd vmsvc/power.on $MYVM

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
