export ipfs_staging=/data/export
export ipfs_data=/data/ipfs
mkdir -p $ipfs_staging $ipfs_data
docker run -d --name ipfs_host -v $ipfs_staging:/export -v $ipfs_data:/data/ipfs -p 4001:4001 -p 127.0.0.1:8080:8080 -p 127.0.0.1:5001:5001 ipfs/go-ipfs:latest


it took 9 minutes to pin 13gb within a datacenter 53881 nodes.
237 Mb/s (megabits per second)
not sure if thats good or not
a bunch of cc0 models
bafybeidinwqhofy2kcmt5lj56e5jipwgjqo6eiu6vvnt3qvflc7xp3xx5i


12:09
get about 
30MB/s

adding 15.71GiB (4 tared files) took 59s. it will take a very long time to add all the small files.ss


to install ipfs run


https://dist.ipfs.io/go-ipfs/versions
```
# /bin/bash
ipfs_version=$(curl -s https://dist.ipfs.io/go-ipfs/versions | tail -1)
tmp_dir=$(mktemp -d)
cd $tmp_dir
curl "https://dist.ipfs.io/go-ipfs/${ipfs_version}/go-ipfs_${ipfs_version}_linux-amd64.tar.gz" | tar -xvz
bash go-ipfs/install.sh
cd -
rm -rf $tmp_dir
```

https://github.com/dhappy/git-remote-ipfs


```
lsblk -I 8 -d

DEVNAME=/dev/sdb
PART_DEV=${DEVNAME}1
MOUNT_PATH=/datadrive
parted ${DEVNAME} --script mklabel gpt mkpart xfspart xfs 0% 100%
mkfs.xfs ${PART_DEV}
partprobe ${PART_DEV}
mkdir /datadrive
mount ${PART_DEV} /datadrive
eval blkid -o export ${PART_DEV}
echo UUID=${PARTUUID}  ${MOUNT_PATH}   xfs   defaults,nofail   1   2 >> /etc/fstab
```


QmPb5KdLLzLDiLbaPTshuGc8XTsfFK55WFDg7wEgQt6U4h is some roms.
