# How to create EBS on AWS and attach it to a EC2 instance
# First need to create the EBS using the wizard in AWS managment console

# Then try connecting to the EC2 instance using CLI(Putty used here)
# After connecting to instance in CLI

# To view storage available on instance
df -h
# Output(similar to the following):
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        471M     0  471M   0% /dev
tmpfs           479M     0  479M   0% /dev/shm
tmpfs           479M  464K  478M   1% /run
tmpfs           479M     0  479M   0% /sys/fs/cgroup
/dev/nvme0n1p1  8.0G  1.5G  6.6G  19% /
tmpfs            96M     0   96M   0% /run/user/0
tmpfs            96M     0   96M   0% /run/user/1000

# Create an ext3 file system on the new volume
sudo mkfs -t ext3 /dev/sdf

# Output:
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
65536 inodes, 262144 blocks
13107 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=268435456
8 block groups
32768 blocks per group, 32768 fragments per group
8192 inodes per group
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

# Create a directory for mounting the new storage volume
sudo mkdir /mnt/data-store

# Mount the new volume
sudo mount /dev/sdf /mnt/data-store

#Output:
mount: /mnt/data-store: /dev/nvme1n1 already mounted on /mnt/data-store.

echo "/dev/sdf   /mnt/data-store ext3 defaults,noatime 1 2" | sudo tee -a /etc/fstab
Output:
/dev/sdf   /mnt/data-store ext3 defaults,noatime 1 2

# View the configuration file
cat /etc/fstab

# Output:
#
UUID=4fcbcd48-c318-4b91-bb26-316cadc02be8     /           xfs    defaults,noatim                          e  1   1
/dev/sdf   /mnt/data-store ext3 defaults,noatime 1 2

# View the available storage again
df -h

# Output with one additional line for new volume:
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        471M     0  471M   0% /dev
tmpfs           479M     0  479M   0% /dev/shm
tmpfs           479M  496K  478M   1% /run
tmpfs           479M     0  479M   0% /sys/fs/cgroup
/dev/nvme0n1p1  8.0G  1.5G  6.6G  19% /
tmpfs            96M     0   96M   0% /run/user/0
tmpfs            96M     0   96M   0% /run/user/1000
/dev/nvme1n1    976M  1.3M  924M   1% /mnt/data-store

# On the mounted volume, create a file and add some text to it
sudo sh -c "echo some text has been written > /mnt/data-store/file.txt"

# Verify that the etxt has been written
cat /mnt/data-store/file.txt

# After verification, delete the text file from created volume
sudo rm /mnt/data-store/file.txt

# Verify that file is deleted
ls /mnt/data-store/

# After building a new snapshot and then building a ne volume and attaching EC2 instance to it, mount the Restored Volume
sudo mkdir /mnt/data-store2

# Mount the new volume
sudo mount /dev/sdg /mnt/data-store2

# Verify the mounted volume has the text file that has been created previousely before taking snapshot
ls /mnt/data-store2/

#Output:
file.txt  lost+found


