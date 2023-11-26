from kubernetes import client, config

config.load_kube_config()
number_to_scale = input(f"Choose number of replicas for all deployments in the cluster (expect `kube-system`): ")

def get_namespaces():
    v1 = client.AppsV1Api()
    ret = v1.list_deployment_for_all_namespaces(watch=False)
    for i in ret.items:
        if i.metadata.namespace != 'kube-system' and i.spec.replicas >= 1:
            print(f"This deployment will be {'descaled' if i.spec.replicas > int(number_to_scale) else ( 'not changed' if i.spec.replicas == int(number_to_scale) else 'scaled' )}:\n ns='{i.metadata.namespace}'\n name='{i.metadata.name}'\n current number of replicas='{i.spec.replicas}'\n")
            body = {'spec':{'replicas': int(number_to_scale)}}
            try:
                v1.patch_namespaced_deployment_scale(name=i.metadata.name,namespace=i.metadata.namespace,body=body)
            except ApiException as e:
                    print(f"Exception when calling AppsV1Api->replace_namespaced_deployment_scale: {e}\n")
get_namespaces()
