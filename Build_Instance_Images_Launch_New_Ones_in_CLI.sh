# Get the volume ID of the EBS for instance
aws ec2 describe-instances
aws ec2 describe-instances --filter 'Name=tag:Name,Values=Processor'
aws ec2 describe-instances --filter 'Name=tag:Name,Values=Processor' --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.{VolumeId:VolumeId}'

#Output:
{
    "VolumeId": "vol-061dbb58ae16be7d4"
}

# Before taking snapshot of the instance, it should be stopped first. Therefore find the instance ID first
aws ec2 describe-instances --filters 'Name=tag:Name,Values=Processor' --query 'Reservations[0].Instances[0].InstanceId'

#Output:
"i-0571c0e5963cf9c47"

aws ec2 stop-instances --instance-ids INSTANCE-ID
aws ec2 stop-instances --instance-ids i-0571c0e5963cf9c47

#Output:
{
    "StoppingInstances": [
        {
            "CurrentState": {
                "Code": 64,
                "Name": "stopping"
            },
            "InstanceId": "i-0571c0e5963cf9c47",
            "PreviousState": {
                "Code": 16,
                "Name": "running"
            }
        }
    ]
}

#Verify that the instance is stopped
aws ec2 wait instance-stopped --instance-id i-0571c0e5963cf9c47

# To create a snapshot of the volume
aws ec2 create-snapshot --volume-id VOLUME-ID
aws ec2 create-snapshot --volume-id vol-061dbb58ae16be7d4

#Output:
{
    "Description": "",
    "Encrypted": false,
    "OwnerId": "893861031781",
    "Progress": "",
    "SnapshotId": "snap-020b5a0e198abe286",
    "StartTime": "2022-05-13T16:12:00.748Z",
    "State": "pending",
    "VolumeId": "vol-061dbb58ae16be7d4",
    "VolumeSize": 8,
    "Tags": []
}

#Verify that snapshot is created
aws ec2 wait snapshot-completed --snapshot-id SNAPSHOT-ID
aws ec2 wait snapshot-completed --snapshot-id snap-020b5a0e198abe286

#Restart the processor instance
aws ec2 start-instances --instance-ids INSTANCE-ID
aws ec2 start-instances --instance-ids i-0571c0e5963cf9c47

#Output:
{
    "StartingInstances": [
        {
            "CurrentState": {
                "Code": 0,
                "Name": "pending"
            },
            "InstanceId": "i-0571c0e5963cf9c47",
            "PreviousState": {
                "Code": 80,
                "Name": "stopped"
            }
        }
    ]
}

# Check the status of restart command
aws ec2 wait instance-running --instance-id INSTANCE-ID
aws ec2 wait instance-running --instance-id i-0571c0e5963cf9c47

# Create a cron entry to schedule for running every minute
echo "* * * * *  aws ec2 create-snapshot --volume-id VOLUME-ID 2>&1 >> /tmp/cronlog" > cronjob
echo "* * * * *  aws ec2 create-snapshot --volume-id vol-061dbb58ae16be7d4 2>&1 >> /tmp/cronlog" > cronjob

# To schedule the cron job
crontab cronjob

# Verify that subsequent snapshots are being created
aws ec2 describe-snapshots --filters "Name=volume-id,Values=<volume-id>"
aws ec2 describe-snapshots --filters "Name=volume-id,Values=vol-061dbb58ae16be7d4"

#Output:
{
    "Snapshots": [
        {
            "Description": "",
            "Encrypted": false,
            "OwnerId": "893861031781",
            "Progress": "100%",
            "SnapshotId": "snap-01cecb9c076f87418",
            "StartTime": "2022-05-13T16:19:02.804Z",
            "State": "completed",
            "VolumeId": "vol-061dbb58ae16be7d4",
            "VolumeSize": 8,
            "StorageTier": "standard"
        },
        {
            "Description": "",
            "Encrypted": false,
            "OwnerId": "893861031781",
            "Progress": "90%",
            "SnapshotId": "snap-07c219f359607a993",
            "StartTime": "2022-05-13T16:20:02.676Z",
            "State": "pending",
            "VolumeId": "vol-061dbb58ae16be7d4",
            "VolumeSize": 8,
            "StorageTier": "standard"
        },
        {
            "Description": "",
            "Encrypted": false,
            "OwnerId": "893861031781",
            "Progress": "100%",
            "SnapshotId": "snap-020b5a0e198abe286",
            "StartTime": "2022-05-13T16:12:00.748Z",
            "State": "completed",
            "VolumeId": "vol-061dbb58ae16be7d4",
            "VolumeSize": 8,
            "StorageTier": "standard"
        }
    ]
}

# Now create Puthon script to just keep the last two created snapshots. Before that, need to stop the cron job that previousely created and running
crontab -r

# Examine a file
more snapshotter_v2.py

# Output, which is a Python script:
#!/usr/bin/env python

import boto3

MAX_SNAPSHOTS = 2   # Number of snapshots to keep

# Create the EC2 resource
ec2 = boto3.resource('ec2')

# Get a list of all volumes
volume_iterator = ec2.volumes.all()

# Create a snapshot of each volume
for v in volume_iterator:
  v.create_snapshot()

  # Too many snapshots?
  snapshots = list(v.snapshots.all())
  if len(snapshots) > MAX_SNAPSHOTS:

    # Delete oldest snapshots, but keep MAX_SNAPSHOTS available
    snap_sorted = sorted([(s.id, s.start_time, s) for s in snapshots], key=lambda k: k[1])
    for s in snap_sorted[:-MAX_SNAPSHOTS]:
      print("Deleting snapshot", s[0])
      s[2].delete()

# Before running the Python script, run the following
aws ec2 describe-snapshots --filters "Name=volume-id, Values=VOLUME-ID" --query 'Snapshots[*].SnapshotId'
aws ec2 describe-snapshots --filters "Name=volume-id, Values=vol-061dbb58ae16be7d4" --query 'Snapshots[*].SnapshotId'

# Output:
[
    "snap-01cecb9c076f87418",
    "snap-07c219f359607a993",
    "snap-020b5a0e198abe286",
    "snap-0b64ccb319a98ef25",
    "snap-00ede621797809023",
    "snap-0fd4672ca96741402"
]

python3 snapshotter_v2.py

# Output:
Deleting snapshot snap-020b5a0e198abe286
Deleting snapshot snap-01cecb9c076f87418
Deleting snapshot snap-07c219f359607a993
Deleting snapshot snap-00ede621797809023
Deleting snapshot snap-0fd4672ca96741402

# Re-run the previous command to verify the remaining snapshots
aws ec2 describe-snapshots --filters "Name=volume-id, Values=vol-061dbb58ae16be7d4" --query 'Snapshots[*].SnapshotId'

# Output:
[
    "snap-0b64ccb319a98ef25",
    "snap-06079b801dca5b9eb"
]

# Now, download a zipped folder that contains 3 text files, unzip them and then sync them to S3 bucket that already created
# But before that, need to enable bucket versioning for the S3 bucket
aws s3api put-bucket-versioning --bucket S3-BUCKET-NAME --versioning-configuration Status=Enabled
aws s3api put-bucket-versioning --bucket s3-bucket-name2 --versioning-configuration Status=Enabled

# Sunc the 3 text files already unzipped to the S3 bucket
aws s3 sync files s3://S3-BUCKET-NAME/files/
aws s3 sync files s3://s3-bucket-name2/files/

# Output:
upload: files/file1.txt to s3://s3-bucket-name2/files/file1.txt
upload: files/file3.txt to s3://s3-bucket-name2/files/file3.txt
upload: files/file2.txt to s3://s3-bucket-name2/files/file2.txt

# Now, delete one of the files
rm files/file1.txt

# To delete the same file from server, use --delete option wth aws s3 sync
aws s3 sync files s3://s3-bucket-name2/files/ --delete

# Verify that the file is deleted remotely on the server
aws s3 ls s3://s3-bucket-name2/files/

# Now, try to recover a version of files1.txt
aws s3api list-object-versions --bucket s3-bucket-name2 --prefix files/file1.txt

# Output:
{
    "Versions": [
        {
            "ETag": "\"b76b2b775023e60be16bc332496f8409\"",
            "Size": 30318,
            "StorageClass": "STANDARD",
            "Key": "files/file1.txt",
            "VersionId": "rItXGOpQLSXsu46ZRq.Khcvj.Gph6F7E",
            "IsLatest": false,
            "LastModified": "2022-05-13T16:48:21.000Z",
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            }
        },
        {
            "ETag": "\"3265fc3a6cf0337a5684731be0076dc2\"",
            "Size": 43784,
            "StorageClass": "STANDARD",
            "Key": "files/file1.txt/file2.txt",
            "VersionId": "j8us6ycgPdQVXWwf7eEKYtOHvFNSSxvz",
            "IsLatest": false,
            "LastModified": "2022-05-13T16:58:30.000Z",
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            }
        },
        {
            "ETag": "\"f491957bee64c931c32fc1d39ffc709f\"",
            "Size": 96675,
            "StorageClass": "STANDARD",
            "Key": "files/file1.txt/file3.txt",
            "VersionId": "hjhI_WyTMiqrEvVH_eEjh15FvYUcfZ_h",
            "IsLatest": false,
            "LastModified": "2022-05-13T16:58:30.000Z",
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            }
        }
    ],
    "DeleteMarkers": [
        {
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            },
            "Key": "files/file1.txt",
            "VersionId": "EecCuLsxAavcFov7alvmEEUEGB447tpj",
            "IsLatest": true,
            "LastModified": "2022-05-13T17:02:44.000Z"
        },
        {
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            },
            "Key": "files/file1.txt/file2.txt",
            "VersionId": "e0hXRUBlnuQ0jZtWdyXUkEMFBneiSBf5",
            "IsLatest": true,
            "LastModified": "2022-05-13T17:02:44.000Z"
        },
        {
            "Owner": {
                "DisplayName": "awslabsc0w4032966t1647847957",
                "ID": "d3e34e649c56bf2c67b0859194ee13dc8a2f4dee993b824d8415e491c8b42042"
            },
            "Key": "files/file1.txt/file3.txt",
            "VersionId": "jewqSevEapnU9J1OmdYafiN5EGz4POqH",
            "IsLatest": true,
            "LastModified": "2022-05-13T17:02:44.000Z"
        }
    ]
}

# Now, need to download the old version and then re-upload it to S3 bucket
aws s3api get-object --bucket S3-BUCKET-NAME --key files/file1.txt --version-id VERSION-ID files/file1.txt
aws s3api get-object --bucket s3-bucket-name2 --key files/file1.txt --version-id rItXGOpQLSXsu46ZRq.Khcvj.Gph6F7E files/file1.txt

# Output:
{
    "AcceptRanges": "bytes",
    "LastModified": "Fri, 13 May 2022 16:48:21 GMT",
    "ContentLength": 30318,
    "ETag": "\"b76b2b775023e60be16bc332496f8409\"",
    "VersionId": "rItXGOpQLSXsu46ZRq.Khcvj.Gph6F7E",
    "ContentType": "text/plain",
    "Metadata": {}
}

# Verify that the files is restored locally
ls files

# re-sync files to S3 bucket


# To verify that a new version of file1.txt has been pushed to S3 bucket run the following
aws s3 ls s3://s3-bucket-name2/files/

