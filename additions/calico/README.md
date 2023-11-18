## Install Calico


[Install Calico Guide](https://docs.tigera.io/calico/3.25/getting-started/kubernetes/helm#install-calico)


### Download the Helm chart

Add the Calico helm repo:

```bash
helm repo add projectcalico https://docs.tigera.io/calico/charts
```
### Customize the Helm chart


```bash
echo '{ installation: {kubernetesProvider: EKS }}' > values.yaml
```

Add any other customizations you require to values.yaml. You might like to refer to the helm docs or run

```bash
helm show values projectcalico/tigera-operator --version v3.26.3
```
to see the values that can be customized in the chart.

### Install Calico

Create the tigera-operator namespace.

```bash
kubectl create namespace tigera-operator
```
Install the Tigera Calico operator and custom resource definitions using the Helm chart:

```bash
helm install calico projectcalico/tigera-operator --version v3.26.3 --namespace tigera-operator
```
or if you created a values.yaml above:

```bash
helm install calico projectcalico/tigera-operator --version v3.26.3 -f values.yaml --namespace tigera-operator
```

Confirm that all of the pods are running with the following command.

```bash
watch kubectl get pods -n calico-system
```
Wait until each pod has the STATUS of Running.

    note

    The Tigera operator installs resources in the calico-system namespace. Other install methods may use the kube-system namespace instead.

Congratulations! You have now installed Calico using the Helm 3 chart.


### Configure VPC CNI Plugin

[AWS Calico guide](https://docs.aws.amazon.com/eks/latest/userguide/calico.html)

If you're using version 1.9.3 or later of the Amazon VPC CNI plugin for Kubernetes, then enable the plugin to add the Pod IP address to an annotation in the calico-kube-controllers-55c98678-gh6cc Pod spec. For more information about this setting, see ANNOTATE_POD_IP

on GitHub.

    See which version of the plugin is installed on your cluster with the following command.

```bash
kubectl describe daemonset aws-node -n kube-system | grep amazon-k8s-cni: | cut -d ":" -f 3
```
An example output is as follows.

```bash
v1.12.2-eksbuild.1
```
Create a configuration file that you can apply to your cluster that grants the aws-node Kubernetes clusterrole the permission to patch Pods.

```bash
cat << EOF > append.yaml
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - patch
EOF
```

Apply the updated permissions to your cluster.

```bash
kubectl apply -f <(cat <(kubectl get clusterrole aws-node -o yaml) append.yaml)
```
Set the environment variable for the plugin.

```bash
kubectl set env daemonset aws-node -n kube-system ANNOTATE_POD_IP=true
```
Delete the calico-kube-controllers-55c98678-gh6cc

```bash
kubectl delete pod calico-kube-controllers-55c98678-gh6cc -n calico-system
```
View the Pods in the calico-system namespace again to see the ID of the new calico-kube-controllers Pod that Kubernetes replaced the calico-kube-controllers-55c98678-gh6cc Pod that you deleted in the previous step with.

```bash
kubectl get pods -n calico-system
```
Confirm that the vpc.amazonaws.com/pod-ips annotation is added to the new calico-kube-controllers Pod.

    Replace 5cd7d477df-2xqpd with the ID for the Pod returned in a previous step.

```bash
kubectl describe pod calico-kube-controllers-5cd7d477df-2xqpd -n calico-system | grep vpc.amazonaws.com/pod-ips
```
An example output is as follows.
```bash
vpc.amazonaws.com/pod-ips: 10.0.17.105
```
