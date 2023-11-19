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


CREATE USER 'wp'@'%' IDENTIFIED BY 'SKdhMAHZHzzU5BEUfKeZ';
GRANT ALL PRIVILEGES ON * . * TO 'wp'@'%';


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
