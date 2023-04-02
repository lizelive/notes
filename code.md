to install code tunnel

```
curl -Ls 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' | tar zxf -

```


```
wget https://aka.ms/vscode-server-launcher/x86_64-unknown-linux-gnu -O code-server && chmod +x code-server && ./code-server serve-local
```


ssh to remote and start code server
```
ssh -L 8000:localhost:8000 192.168.0.5  sudo docker run --rm --name=mlws --net=host --gpus=all --ipc=host --ulimit memlock=-1 --ulimit stack=67108864 -i -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -v lizelive-home:/home/lizelive/ -v /tmp:/tmp -v /var/cache:/var/cache -u 1000:100 -w /home/lizelive huggingface/transformers-pytorch-deepspeed-latest-gpu ./code-server serve-local --quality=insiders
```
