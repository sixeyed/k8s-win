# Kubernetes on Windows

Scripts for setting up a local hybrid Kubernetes cluster, with a Linux master, Linux worker and Windows worker. Currently deploys:

- Docker 19.03.0
- Kubernetes 1.15.1

> The setup is documented here: [Getting Started with Kubernetes on Windows](https://blog.sixeyed.com/getting-started-with-kubernetes-on-windows/).

## Apps

There are also Kubernetes manifests for some [sample apps](./apps/README.md), running in Windows and Linux pods.

### Credits

The scripts are mostly hacked together from other scripts and docs:

- [Guide for adding Windows Nodes in Kubernetes](https://kubernetes.io/docs/setup/production-environment/windows/user-guide-windows-nodes/)

- [Kubernetes on Windows](https://docs.microsoft.com/en-us/virtualization/windowscontainers/kubernetes/getting-started-kubernetes-windows)
