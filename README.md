# Infrastructure Repository


# Requirements
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

# Steps

## Bootstrap de cluster
```
cd vm
vagrant up
```
1. Deploy vm
2. Install requirements:
    - docker
    - kind
    - flux
    - kubectl
    - helm
    - kubeseal
3. Bootstrap of K8s cluster
    - Start Kind cluster
    - Install Cilium as CNI
    - Deploy Flux controllers
    - Deploy SealedSecrets controllers

## Connect to de cluster node
```
ssh vagrant@192.168.56.210
# pass: vagrant
```
> Note. known_hosts

## Clean environment
```
cd vm
vagrant destroy
```