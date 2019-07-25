#!/bin/bash

# copy the config & write it out
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

clear
cat $HOME/.kube/config