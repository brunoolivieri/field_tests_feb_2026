#!/bin/bash

sudo ip route replace default via 139.82.100.65
sudo echo "nameserver 139.82.16.3" >> /etc/resolv.conf
sudo echo "nameserver 8.8.8.8" >> /etc/resolv.conf
