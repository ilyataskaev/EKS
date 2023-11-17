# EKS Cluster Management Script

This Bash script manages the creation and destruction of an Amazon EKS cluster using `eksctl`. It supports deploying a new cluster with specific configurations like region, node type, and VPC CIDR. Additionally, it can install a cluster autoscaler and NGINX Ingress controller.

## Prerequisites
- AWS CLI installed and configured
- `eksctl` installed
- `kubectl` installed
- Helm installed (for NGINX Ingress)

## Configuration
- `region`: AWS region (default `eu-central-1`)
- `version`: EKS version (default `'1.27'`)
- `cidr`: VPC CIDR (default `'10.0.0.0/16'`)
- `node_type`: EC2 instance type for nodes (default `'t2.small'`)

## Usage

To **create** a cluster:
```bash
./cluster.sh -c [name of the cluster]
```

To **destroy** a cluster:

```bash
./cluster.sh -d [name of the cluster]
```

Example:

```bash
./cluster.sh -c eks-2023
./cluster.sh -d eks-2023
```

Functions

- `create_cluster`: Creates a new EKS cluster with the specified configurations.
- `install_autoscaler`: Installs the Kubernetes cluster autoscaler.
- `install_ingress_nginx`: Installs the NGINX Ingress controller using Helm.
- `destroy_ingress_nginx`: Uninstalls the NGINX Ingress controller.
- `delete_cluster`: Deletes the specified EKS cluster and associated resources.

The script includes additional helper functions and error handling to streamline the process of managing EKS clusters.
