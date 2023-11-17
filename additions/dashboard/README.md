## Install K8S Dashboard

First, install the Kubernetes Dashboard using the following command. This will apply the recommended setup for the dashboard.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### Verification

After installation, verify if all the necessary resources have been created successfully in the `kubernetes-dashboard` namespace.

```bash
kubectl get all -n kubernetes-dashboard
```

### Create Service Account

Create a service account that will be used for dashboard access. This step is crucial for setting up the right permissions.

```bash
kubectl apply -f admin-user-account.yaml
```

### Install Metrics Server

The metrics server is required for getting metrics like CPU and memory usage. Install it using the following command.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Get Token

Generate a token for the admin user. This token will be used to log into the dashboard.

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

### Access Dashboard

Start the Kubernetes proxy. This will create a secure connection to your Kubernetes cluster from your local machine.

```bash
kubectl proxy
```

After running the `kubectl proxy` command, access the dashboard using the following URL: [Dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/workloads?namespace=_all). Use the token generated in the previous step to log in.
