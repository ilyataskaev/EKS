## Create Stateful Wordpress app

```bash
k create ns statefull
```

```bash
PASSWORD=$(openssl rand -base64 15)
k create secret generic mysql-pass --from-literal=password=$PASSWORD -n statefull
```

```bash
k apply -f pvcs.yaml
```

```bash
kubectl exec vault-0 -- vault write database/config/mysql \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(mysql.statefull.svc.cluster.local:3306)/" \
    allowed_roles="readonly,readwrite" \
    username="root" \
    password="$ROOT_PASSWORD"
```

```bash
kubectl exec vault-0 -- vault write database/roles/readonly \
    db_name=mysql \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"
```

```bash
kubectl exec vault-0 -- vault write database/roles/readwrite \
    db_name=mysql \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"
```

```bash
vault policy write wordpress - <<EOF
path "database/creds/readonly" {
  capabilities = ["read"]
}
path "database/creds/readwrite" {
  capabilities = ["read"]
}
EOF
```

```bash
vault write auth/kubernetes/role/wordpress-app \
      bound_service_account_names=wordpress-app \
      bound_service_account_namespaces=statefull \
      policies=wordpress \
      ttl=24h
```

Install ClusterIssuer
```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-statefull
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: ansustiwaz@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-statefull
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          serviceType: ClusterIP
          ingressClassName: nginx
EOF
```
Generate certificate for `wp.rusty.systems` domain:

```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wp-cert
  #namespace: cert-manager
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

** Please be patient while the chart is being deployed **

Tip:

  Watch the deployment status using the command: `kubectl get pods -w --namespace statefull`

Services:

  echo Primary: mysql.statefull.svc.cluster.local:3306

Execute the following to get the administrator credentials:

```bash
echo Username: root
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace statefull mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode)
```

To connect to your database:

  1. Run a pod that you can use as a client:

```bash
kubectl run mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.29-debian-10-r21 --namespace statefull --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
```
  2. To connect to primary service (read/write):

```bash
mysql -h mysql.statefull.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"
```
