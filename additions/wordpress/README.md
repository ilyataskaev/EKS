# Namespace and PVC

## Create namespace
```bash
k create ns statefull
```
## Apply Persistent Volume Claims

```bash
k apply -f pvcs-wordpress.yaml
```

# Cert Manager
## Install ClusterIssuer for Let's Encrypt

```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-statefull
spec:
  acme:
    email: ansustiwaz@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-statefull
    solvers:
    - http01:
        ingress:
          serviceType: ClusterIP
          ingressClassName: nginx
EOF
```
## Generate certificate for wp.rusty.systems domain
```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wp-cert
spec:
  commonName: wp.rusty.systems
  secretName: wp-cert
  dnsNames:
    - wp.rusty.systems
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-statefull
EOF
```

# Install Mysql

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mysql bitnami/mysql -n statefull

```
## Watch the deployment status
```bash
echo "Watch deployment status with: kubectl get pods -w --namespace statefull"
```
## Get administrator credentials

```bash
echo "Get MySQL admin credentials:"
echo "Username: root"
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace statefull mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
```
## Connect to the database
Run a client pod:
```bash
kubectl run mysql-client --rm --tty -i --restart='Never' --image docker.io/bitnami/mysql:8.0.29-debian-10-r21 --namespace statefull --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
```
Connect to primary service as root (read/write):
```bash
echo "mysql -h mysql.statefull.svc.cluster.local -uroot -p\"\$MYSQL_ROOT_PASSWORD\""
```

Create a new MYSQL user and password:
```bash
WP_DB_PASSWORD=$(openssl rand -base64 15)
create user 'WP_USER'@'%' identified by ${WP_DB_PASSWORD};
grant all privileges on WP_DB.* TO 'WP_USER'@'%';
flush privileges;

```
## Deploy Wordpress
Create a Secret
```bash
k create secret generic mysql-pass --from-literal=db_user=WP_USER --from-literal=db_name=WP_DB --from-literal=password=${WP_DB_PASSWORD}
```

Deploy WP:
```bash
k apply -f deploy-wordpress.yaml
```

Deploy WP Ingress:
```bash
k apply -f ingress-wp.yaml
```
