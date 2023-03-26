# zfs

find disks `sudo fdisk -l`

`sudo zpool create -f ftcg /dev/sdb /dev/sdc`

same permisions as /tmp
`sudo chmod 1777 /ftcg`

`nix-shell -p iozone`

`iozone -a -s 4m -r 4k -i 0 -i 1 -i 2 -f /ftcg/iozone.tmp`

get permisions as number
`stat -c '%a %n' /tmp/`




set acl permisions
`setfacl -dm u::rwx,g::rwx,o::r`

```
                                                              random    random     bkwd    record    stride                                    
              kB  reclen    write  rewrite    read    reread    read     write     read   rewrite      read   fwrite frewrite    fread  freread
            4096       4  1196302  1346933  3014114  3743865  3303309  1642308                                                                
```
