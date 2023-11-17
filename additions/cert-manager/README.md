## Install Cert Manager

Install Cert Manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
```
Install ClusterIssuer
```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: ansustiwaz@gmail.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource that will be used to store the account's private key.
      name: letsencrypt-prod
    # Add a single challenge solver, HTTP01 using nginx
    solvers:
    - http01:
        ingress:
          serviceType: ClusterIP
          ingressClassName: nginx
EOF
```
Generate certificate for `demo.rusty.systems` domain:

```bash
cat <<EOF | kubectl create -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: demo-cert
  namespace: cert-manager
spec:
  commonName: demo.rusty.systems
  secretName: demo-cert
  dnsNames:
    - demo.rusty.systems
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
EOF
```
Create ingress for the service:
```bash
cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: guestbook
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - demo.rusty.systems
    secretName: demo-cert
  rules:
  - host: demo.rusty.systems
    http:
      paths:
      - path: /redis-client
        pathType: Exact
        backend:
          service:
            name: py-guestbook-frontend
            port:
              number: 5000
EOF
```
