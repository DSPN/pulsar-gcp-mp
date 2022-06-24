#!/bin/bash

export APP_INSTANCE_NAME=pulsar-mp
export NAMESPACE=default

for name in \
    $APP_INSTANCE_NAME-prom-coredns \
    $APP_INSTANCE_NAME-prom-kube-etcd \
    $APP_INSTANCE_NAME-prom-kubelet; do
    kubectl delete service $name -n kube-system
done

for resource_type in \
    persistentvolume \
    persistentvolumeclaim \
    statefulset \
    daemonset \
    deployment \
    replicaset \
    job \
    clusterrole \
    clusterrolebinding \
    configmap \
    mutatingwebhookconfiguration \
    prometheus \
    prometheusrule \
    pod \
    podsecuritypolicy \
    role \
    rolebinding \
    secret \
    service \
    serviceaccount \
    servicemonitor \
    validatingwebhookconfiguration \
    application; do

    kubectl delete "${resource_type}" \
        --selector app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
        --namespace "${NAMESPACE}"
done

