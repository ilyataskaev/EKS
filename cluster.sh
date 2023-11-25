#!/bin/bash
region=eu-central-1
version='1.27'
cidr='10.0.0.0/16'
node_type='t2.small'
account=$(aws sts get-caller-identity --query Account --output text)

usage() {
  cat << EOF
Usage:
    To Start Cluster:
    $0 -c [name of the cluster]

    to Destroy Cluster:
    $0 -d [name of the cluster]

Examples:
    ./cluster.sh -c eks-2023
    ./cluster.sh -d eks-2023
EOF
}

create_cluster() {
  local cluster_name=$1
  local region=$2
  local version=$3
  local vpccidr=$4
  local node_type=$5

  eksctl create cluster \
    --name $cluster_name \
    --region $region  \
    --version ${version} \
    --zones ${region}a,${region}b \
    --vpc-cidr ${vpccidr} \
    --without-nodegroup \
    --asg-access

  eksctl utils associate-iam-oidc-provider \
    --region  $region  \
    --cluster $cluster_name \
    --approve

  eksctl create nodegroup --cluster=$cluster_name \
    --region ${region}  \
    --name ${cluster_name}-ng-private-spot1 \
    --instance-types=t3.small \
    --nodes=1 \
    --nodes-min=1 \
    --nodes-max=3 \
    --node-volume-size=10 \
    --ssh-access \
    --ssh-public-key=eks \
    --managed \
    --asg-access \
    --external-dns-access \
    --full-ecr-access \
    --appmesh-access \
    --alb-ingress-access \
    --node-private-networking \
    --spot
}

create_csi_ebs() {
  set -x
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
    --name aws-ebs-csi-driver \
    --cluster ${cluster_name} \
    --service-account-role-arn arn:aws:iam::${acoount}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force
}

create_csi_efs() {
local role_name=AmazonEKS_EFS_CSI_DriverRole
eksctl create iamserviceaccount \
    --name efs-csi-controller-sa \
    --namespace kube-system \
    --cluster $cluster_name \
    --role-name $role_name \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
    --approve

TRUST_POLICY=$(aws iam get-role --role-name $role_name --query 'Role.AssumeRolePolicyDocument' | \
    sed -e 's/efs-csi-controller-sa/efs-csi-*/' -e 's/StringEquals/StringLike/')

aws iam update-assume-role-policy --role-name $role_name --policy-document "$TRUST_POLICY"

eksctl create addon --cluster $cluster_name --name aws-efs-csi-driver --version v1.7.1-eksbuild.1 \
    --service-account-role-arn arn:aws:iam::385379752235:role/$role_name --force
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

install_ingress_nginx() {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx  \
    --namespace ingress-nginx \
    --create-namespace \
    --set-string controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
}

destroy_ingress_nginx() {
  helm uninstall ingress-nginx -n ingress-nginx
}

delete_cluster() {
  local cluster_name=$1
  local region=$2
  eksctl delete nodegroup --region=$region  --cluster=${cluster_name} --name=${cluster_name}-ng-public1
  eksctl delete cluster   --region=$region  --name=${cluster_name}
}

if [ $# -eq 0 ]; then
    echo "No arguments provided."
    usage
fi

while getopts "c:d:" OPTKEY; do
    case "${OPTKEY}" in
        'c')
            printf "Creating Cluster ${OPTARG}\n"
            create_cluster ${OPTARG} ${region} ${version} ${cidr} ${node_type}
            sleep 10
            install_ingress_nginx
            install_autoscaler
            create_csi_ebs
            create_csi_efs
          ;;
        'd')
            while true; do
                read -p "Do you really want to delete the cluster '${OPTARG}'? (Yes/No) " yn
                case $yn in
                    [Yy]* ) break;;  # If yes, break the loop and continue with deletion
                    [Nn]* ) echo "Cluster deletion cancelled."; return;;
                    * ) echo "Please answer Yes or No.";;
                esac
            done
            printf "Deleting Cluster ${OPTARG}\n"
            destroy_ingress_nginx
            delete_cluster ${OPTARG} ${region}
          ;;
        ':')
            printf "\nERROR: MISSING ARGUMENT for option -- ${OPTARG}"
            exit 1
            ;;
        *)
            usage && exit 1
            ;;
    esac
done
shift $((OPTIND-1))
