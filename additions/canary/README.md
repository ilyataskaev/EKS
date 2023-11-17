## Canary Deployment

Create Firrst Deployment:

```
k create deployment app-py --image docker.io/ansustiwaz/app-py:latest --port=5000
k expose deployment app-py
k create ingress app-py --class=nginx --rule www.ingress.com/=app-py:5000
```
Test it:
```
#Get IP:
curl -v a6598b65f85a84a1db747818884ab616-d2ec479b023b351e.elb.eu-central-1.amazonaws.com
curl --resolve www.ingress.com:80:<IP_ADDRESS_OF_NLB> http://www.ingress.com
```

```
k get ingress app-py
k create deployment app-py --image docker.io/ansustiwaz/app-py:v2 --port=5000
k create deployment app-py --image docker.io/ansustiwaz/app-py:v3 --port=5000
expose deployment app-py-v2
expose deployment app-py-v3
```
