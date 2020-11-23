
it took 9 minutes to pin 13gb within a datacenter 53881 nodes.
28.25 MiB/s
not sure if thats good or not
a bunch of cc0 models
bafybeidinwqhofy2kcmt5lj56e5jipwgjqo6eiu6vvnt3qvflc7xp3xx5i


12:09
get about 
30MB/s

adding 15.71GiB (4 tared files) took 59s. it will take a very long time to add all the small files.ss




Run ipfs as docker
```
export ipfs_staging=/data/export
export ipfs_data=/data/ipfs
mkdir -p $ipfs_staging $ipfs_data
docker run -d --name ipfs_host -v $ipfs_staging:/export -v $ipfs_data:/data/ipfs -p 4001:4001 -p 127.0.0.1:8080:8080 -p 127.0.0.1:5001:5001 ipfs/go-ipfs:latest
echo "alias ipfs='docker exec ipfs_host ipfs'" >> /etc/profile.d/00-aliases.sh
```

to install ipfs locally run

```
curl -s https://lizelive.github.io/system/ipfs/install.sh | sudo bash -s
```



use https://github.com/lizelive/system/blob/master/mount.sh to mount stuff


Sample set
UCI ml datasets

Dowload speed 63MiB/s

16gb in 4 mins (that's pretty fast)

to pin it badgerds took 51.090s

downloading to home took 15 mins

copying from the ipfs mount took 128m27s which is bad.









http://image-net.org/small/train_32x32.tar
http://image-net.org/small/valid_32x32.tar
http://image-net.org/small/train_64x64.tar
http://image-net.org/small/valid_64x64.tar


quickstart node 
```
sudo apt install docker.io
sudo snap install ipfs
ipfs init --profile=server,badgerds -e
ipfs daemon &
```



install textile hub
```
wget -c https://github.com/textileio/textile/releases/download/v2.1.6/hub_v2.1.6_linux-amd64.tar.gz -O - | tar -xz
````

15Mib/s for torrent speed


## art bench
# 514 MB pinned at home and filepinatia
pinned QmNwjvRPrECRBYAeMgpFNcWRNEbpNKtKvs5aggjGL5rena recursively

real	10m31.718s
user	0m0.499s
sys	0m0.095s

0.7781 MiB/s (thats horrible)

it seems that low quality nodes substanitally degrade the performance of the network.

