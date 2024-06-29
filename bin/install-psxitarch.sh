#!/bin/sh

mkdir /temp
mkdir /backup

echo "Try to find the right usb"
for x in a b c d e f g h i j k
do
	device="/dev/sd"$x
    mount $device"1" /temp
    if [ $? = 0 ]; then
		if [ -e /temp/bzImage ] && [ -e /temp/initramfs.cpio.gz ] && [ -e /temp/psxitarch.tar.gz ]; then
			echo "Device $device has the necessary files to install psxitarch linux"
			break;
		fi
		umount $device"1"
	fi
	if [ $x = "k" ]; then
		echo "ERROR! No valid usb device found! Try remove, reinsert the usb device and run again install-psxitarch.sh"
		echo "If the error persist probably your usb device is not formatted as FAT32 or some files are missing or corrupted" 
		exit
	fi
done

notmbr=$(fdisk -l $device | grep -i "gpt")
if [ "$notmbr" != "" ]; then
    echo "ERROR! Your USB device don't has a MBR partition table, please convert the partition table to MBR (MS-DOS (FAT32))"
    exit
fi

sizeusb=$(fdisk -l | grep -i "Disk $device" | awk '{print $3}')
mu=$(fdisk -l | grep -i "Disk $device" | awk '{print $4}')
sizeusb=$(echo $sizeusb | awk -F',' '{print $1}')
mu=$(echo $mu | awk -F',' '{print $1}')

echo "Size usb device: $sizeusb $mu"
if [ "$mu" != "GB" ] || [ $sizeusb -lt 22 ]; then
	echo "ERROR! Not enough space on the usb device, please insert one usb with almost 22GB of free space and run again install-psxitarch.sh"
	exit
fi

echo "Copy psxitarch, the bzImage and the initramfs to /backup"
cp /temp/psxitarch.tar.gz /backup
if [ $? -ne  0 ]; then
	echo "ERROR! Not enough space in RAM available!"
	echo "Use payload 1GB VRAM"
	exit
fi
cp /temp/initramfs.cpio.gz /backup
if [ $? -ne  0 ]; then
	echo "ERROR! Not enough space in RAM available!"
	echo "Use payload 1GB VRAM"
	exit
fi
cp /temp/bzImage /backup
if [ $? -ne  0 ]; then
	echo "ERROR! Not enough space in RAM available!"
	echo "Use payload 1GB VRAM"
	exit
fi
umount $device"1"

echo "Create a fat32 and an ext4 partition"
(
echo "o" #fdisk can't write device with disklabel GPT
echo "d"
echo "n"
echo "p"
echo "1"
echo '2'
echo "+80M"
echo "n"
echo "p"
echo "2"
echo "2"
echo #default
echo #default
echo "w"
echo "q"
) | fdisk -S 32 -H 64 $device

echo "Format fat32 partition"
mkfs.vfat $device"1"

echo "Remount the fat32 partition and copy in the initramfs and bzImage"
mount $device"1" /temp
cp /backup/initramfs.cpio.gz /temp
cp /backup/bzImage /temp
umount $device"1"

echo "Format the ext4 partition to psxitarch and mount it to /newroot"
mke2fs-new -t ext4 -F -L psxitarch -O ^has_journal $device"2" 
mount $device"2" /newroot

echo "Installing psxitarch linux, please wait, DON'T REMOVE THE USB DEVICE OR SHUTDOWN THE PS4!"
sleep 5

echo "Extract backup of psxitarch to /newroot"
tar -xvpzf /backup/psxitarch.tar.gz -C /newroot --numeric-owner

echo "Psxitarch linux installed with success! Clean some garbage.."
rm /backup/*
rm -R /newroot/lost+found

echo "Add eap key, edid and amdgpu firmware to the distro"
cp /key/eap_hdd_key.bin /newroot/etc/cryptmount
cp /lib/firmware/edid/my_edid.bin /newroot/lib/firmware/edid
cp -R /lib/firmware/amdgpu /newroot/lib/firmware

echo "Booting psxitarch linux, please wait.." 
exec switch_root /newroot /newroot/sbin/init &
sleep 2 &&
exec switch_root /newroot /newroot/sbin/init &
sleep 2 &&
exec switch_root /newroot /newroot/sbin/init
