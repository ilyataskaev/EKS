#!/bin/bash -x

# Default values
region=eu-central-1
version='1.27'
cidr='10.0.0.0/16'
node_type='t3.small,t3.medium'
node_count=1
node_min=1
node_max=3
volume_size=10
ssh_key_name="eks"

account=$(aws sts get-caller-identity --query Account --output text)

check_command() {
  if ! command -v $1 &> /dev/null; then
    echo "$1 not installed, please install: $1"
  fi
}

check_command kubectl
check_command helm
check_command eksctl
check_command aws

usage() {
  cat << EOF
Usage: $0 [options]

Options:
    -c, --create <cluster_name>    Create a new cluster
    -d, --delete <cluster_name>    Delete an existing cluster
    -r, --region <region>          Specify AWS region (default: eu-central-1)
    -v, --version <version>        Specify Kubernetes version (default: 1.27)
    -n, --node-type <node_type>    Specify node types (default: t3.small,t3.medium)
    -N, --node-count <count>       Specify initial node count (default: 1)
    -m, --node-min <count>         Specify minimal node count (default: 1)
    -M, --node-max <count>         Specify maximum node count (default: 3)
    -s, --volume-size <size>       Specify node volume size (default: 10)
    -k, --ssh-key <key_name>       Specify SSH key name (default: eks)

Examples:
    $0 --create eks-2023 --region us-west-2 --node-type t3.large
    $0 --delete eks-2023
EOF
}

create_cluster() {
  local cluster_name=$1
  local region=$2
  local version=$3
  local vpccidr=$4
  local node_type=$5
  local node_count=$6
  local node_min=$7
  local node_max=$8
  local volume_size=$9
  local ssh_key_name=${10}

  eksctl create cluster \
    --name $cluster_name \
    --region $region  \
    --version ${version} \
    --zones ${region}a,${region}b \
    --vpc-cidr ${vpccidr} \
    --without-nodegroup \
    --asg-access \
    --full-ecr-access \
    --external-dns-access

  eksctl utils associate-iam-oidc-provider \
    --region  $region  \
    --cluster $cluster_name \
    --approve

  eksctl create nodegroup --cluster=$cluster_name \
    --region ${region}  \
    --name ${cluster_name}-ng-private-spot1 \
    --instance-types=${node_type} \
    --nodes=${node_count} \
    --nodes-min=${node_min} \
    --nodes-max=${node_max} \
    --node-volume-size=${volume_size} \
    --ssh-access \
    --ssh-public-key=${ssh_key_name} \
    --managed \
    --asg-access \
    --external-dns-access \
    --full-ecr-access \
    --appmesh-access \
    --alb-ingress-access \
    --node-private-networking \
    --spot
}

install_ingress_nginx() {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx  \
    --namespace ingress-nginx \
    --create-namespace \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
}

install_autoscaler() {
  kubectl apply -f cluster-autoscaler-autodiscover.yaml
  if [ $? -ne 0 ]; then
    echo "Failed to apply cluster-autoscaler configuration"
    exit 1
  else
    echo "Cluster autoscaler has been installed successfully."
  fi
  sleep 10
  kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false" --overwrite
}

install_calico() {
  kubectl create namespace tigera-operator
  helm repo add projectcalico https://docs.tigera.io/calico/charts
  helm install calico projectcalico/tigera-operator --version v3.26.3 -f additions/calico/values.yaml --namespace tigera-operator
  kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) additions/calico/append.yaml)
  kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true
  pod_name=$(kubectl get pods -n calico-system | grep calico-kube-controllers | awk '{print $1 }')
  kubectl delete pod $pod_name -n calico-system
  sleep 15
  new_pod_name=$(kubectl get pods -n calico-system | grep calico-kube-controllers | awk '{print $1 }')
  kubectl describe pod $new_pod_name -n calico-system | grep vpc.amazonaws.com/pod-ips
}

install_cert_manager() {
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
  sleep 15
  kubectl create -f additions/cert-manager/cert-issuer.yaml
  echo "Read this instruction next: additions/cert-manager/README.md"
}

create_csi_ebs() {
  local cluster_name=$1
  # https://stackoverflow.com/questions/75758115/persistentvolumeclaim-is-stuck-waiting-for-a-volume-to-be-created-either-by-ex
  # https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
  eksctl create iamserviceaccount \
    --region $region \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster ${cluster_name} \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --role-only \
    --role-name AmazonEKS_EBS_CSI_DriverRole

  eksctl create addon \
    --region $region \
    --name aws-ebs-csi-driver \
    --cluster ${cluster_name} \
    --service-account-role-arn arn:aws:iam::${account}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force
}

create_csi_efs() {
  # https://github.com/kubernetes-sigs/aws-efs-csi-driver/blob/master/docs/README.md
  # https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
  local cluster_name=$1
  eksctl create iamserviceaccount \
    --region $region \
    --name efs-csi-controller-sa \
    --namespace kube-system \
    --cluster $cluster_name \
    --role-name AmazonEKS_EFS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
    --approve

  TRUST_POLICY=$(aws iam get-role --role-name AmazonEKS_EFS_CSI_DriverRole --query 'Role.AssumeRolePolicyDocument' | \
    sed -e 's/efs-csi-controller-sa/efs-csi-*/' -e 's/StringEquals/StringLike/')

  aws iam update-assume-role-policy --role-name AmazonEKS_EFS_CSI_DriverRole --policy-document "$TRUST_POLICY"

  eksctl create addon --region $region \
    --cluster $cluster_name \
    --name aws-efs-csi-driver \
    --version v1.7.1-eksbuild.1 \
    --service-account-role-arn arn:aws:iam::${account}:role/AmazonEKS_EFS_CSI_DriverRole \
    --force
}

confirm_deletion() {
  local cluster_name=$1
  while true; do
      read -p "Do you really want to delete the cluster '${cluster_name}'? (Yes/No) " yn
      case $yn in
          [Yy]* ) break;;  # If yes, break the loop and continue with deletion
          [Nn]* ) echo "Cluster deletion cancelled."; return;;
          * ) echo "Please answer Yes or No.";;
      esac
  done
}

destroy_ingress_nginx() {
  helm uninstall ingress-nginx -n ingress-nginx
}

descale_all_deployments() {
  # Get the list of namespaces, excluding header 'NAME'
  nss=$(kubectl get ns | awk '!/NAME/{print $1}')
  # Iterate over each namespace
  for ns in $nss; do
      # Get the list of deployments in the current namespace
      els=$(kubectl get deployment -n $ns | awk '!/NAME/{print $1}')
      # Iterate over each deployment
      for el in $els; do
          # Scale down the deployment to 0 replicas
          echo "Deleting ${ns}/${el}"
          kubectl scale deployment -n $ns $el --replicas 0
      done
  done
}

delete_cluster() {
  local cluster_name=$1
  local region=$2
  # eksctl delete nodegroup --region=$region  \
  #   --cluster=${cluster_name} \
  #   --name ${cluster_name}-ng-private-spot1 \
  #   --disable-eviction \
  #   --parallel 5
  eksctl delete cluster   --region=$region  --name=${cluster_name}
}

if [ $# -eq 0 ]; then
    echo "No arguments provided."
    usage
fi

# Parsing command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--create)
      action="create"
      cluster_name="$2"
      shift 2
      ;;
    -d|--delete)
      action="delete"
      cluster_name="$2"
      shift 2
      ;;
    -r|--region)
      region="$2"
      shift 2
      ;;
    -v|--version)
      version="$2"
      shift 2
      ;;
    -n|--node-type)
      node_type="$2"
      shift 2
      ;;
    -N|--node-count)
      node_count="$2"
      shift 2
      ;;
    -m|--node-min)
      node_min="$2"
      shift 2
      ;;
    -M|--node-max)
      node_max="$2"
      shift 2
      ;;
    -s|--volume-size)
      volume_size="$2"
      shift 2
      ;;
    -k|--ssh-key)
      ssh_key_name="$2"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# Main logic based on action
case "${action}" in
  "create")
    create_cluster "${cluster_name}" \
      "${region}" \
      "${version}" \
      "${cidr}" \
      "${node_type}" \
      "${node_count}" \
      "${node_min}" \
      "${node_max}" \
      "${volume_size}" \
      "${ssh_key_name}"
    install_ingress_nginx
    install_autoscaler
    create_csi_ebs "${cluster_name}"
    create_csi_efs "${cluster_name}"
    install_calico
    install_cert_manager
    ;;
  "delete")
    confirm_deletion "${cluster_name}"
    descale_all_deployments
    destroy_ingress_nginx
    delete_cluster "${cluster_name}" "${region}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
