#!/bin/bash
apt install curl -y
systemctl stop ddns-go
rm /usr/bin/ddns-go
mkdir ./ddns
cd ./ddns
uname -m | grep -qi aarch64 && oarch=linux_arm64 || oarch=linux_x86_64;
wget "$(curl -s https://api.github.com/repos/jeessy2/ddns-go/releases/latest|grep -i "browser_download_url.*${oarch}"|awk -F '"' '{print $(NF-1)}')";
tar -xzvf ./ddns*.tar.gz
chmod +x ./ddns-go
mv ./ddns-go /usr/bin
cd ..
rm -rf ./ddns
ddns-go -s install
systemctl start ddns-go
