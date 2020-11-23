I want to try hosting a simple docker cr staticly on ipfs.
https://www.redhat.com/sysadmin/how-run-skopeo-container

I saw the tool, but that requires a server to be running.
https://github.com/miguelmota/ipdr


I needed to download [shapoko](https://github.com/containers/skopeo) but becuse i didn't want to do that i ran it on docker
```alias skopeo='docker run --rm -v $PWD:/images quay.io/skopeo/stable'```
this worked fine.
