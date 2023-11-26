#!/bin/bash

# Get the list of namespaces, excluding header 'NAME'
nss=$(kubectl get ns | awk '!/NAME/{print $1}')

# Iterate over each namespace
for ns in $nss; do
    # Get the list of deployments in the current namespace
    els=$(kubectl get deployment -n $ns | awk '!/NAME/{print $1}')

    # Iterate over each deployment
    for el in $els; do
        # Scale down the deployment to 0 replicas
        kubectl scale deployment -n $ns $el --replicas 0
    done
done
