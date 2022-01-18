# Overview
Apache Pulsar on GKE

# Installation

## Quick install with Google Cloud Marketplace
Get up and running with a few clicks! Install the Pulsar marketplace app to a Google Kubernetes Engine cluster by using Google Cloud Marketplace. Follow the [[on-screen-instructions]](https://google.com)

## Command-line instructions
You can use [Google Cloud Shell] or a local workstation to follow the steps below.

### Prerequisites

#### Set up command-line tools

You'll need the following tools in your development environment. If you are using Cloud Shell, these are all installed in your environment by default.

* [gcloud](https://cloud.google.com/sdk/gcloud/)
* [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
* [docker](https://docs.docker.com/install/)
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [helm](https://helm.sh/)
* [kustomize](https://kustomize.io/)

Configure gcloud as a docker credential helper:

```bash
gcloud auth configure-docker
```

#### Create a Google Kubernetes Engine cluster

Create a new cluster from the command line:

```bash
export CLUSTER=pulsar-mp-cluster
export CLUSTER_SIZE=3
export ZONE=us-central1-a
gcloud container clusters create "${CLUSTER}" \
    --zone "$ZONE" \
    --machine-type n1-standard-8 \
    --num-nodes "$CLUSTER_SIZE"
```

Configure kubectl to connect to the cluster:

```bash
gcloud container clusters get-credentials "${CLUSTER}" --zone "${ZONE}"
```

#### Clone this repo

```bash
git clone https://github.com/DSPN/pulsar-gcp-mp.git
```

#### Install the Application resource definition

An Application resource is a collection of individual Kubernetes components, such as Services, Deployments, and so on, that you can manage as a group.

To set up your cluster to understand Application resources, run the following command:

```bash
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

You need to run this command once.

The Application resource is defined by the [Kubernetes SIG-apps](https://github.com/kubernetes/community/tree/master/sig-apps) community. The source code can be found on [github.com/kubernetes-sigs/application](https://github.com/kubernetes-sigs/application).

### Install the Application

#### Navigate to the pulsar-gcp-mp directory

```bash
cd pulsar-gcp-mp
```

#### Download the pulsar charts

```bash
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm dependency build chart/pulsar-mp
```

#### Configure the app with environment variables

Choose an instance name, namespace, and default storage class for the app. In most cases you can use the `default` namespace.

```bash
export APP_INSTANCE_NAME=pulsar-mp
export NAMESPACE=default
export DEFAULT_STORAGE_CLASS=pulsar-storage
```

Set up the image registry, repository, and tag:

```bash
export REGISTRY="gcr.io"
export REPOSITORY="datastax-public/pulsar-mp"
export TAG="2.0"
```

Configure the container images:

```bash
[TODO]
```

#### Create a suitable storage class

Create a storage class that will be used by the Cassandra persistent storage volume claims:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${DEFAULT_STORAGE_CLASS}
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  fstype: ext4
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

#### Create the namespace in your Kubernetes cluster

If you use a namespace other than the `default`, run the command below to create a new namespace.

```bash
kubectl create namespace "${NAMESPACE}"
```

#### Create service accounts and RBAC resources for each of the Pulsar components

[TODO]

#### Expand the manifest template

Use `helm template` to expand the template. We recommend that you save the expanded manifest file for future updates to the application.

```bash
helm template "${APP_INSTANCE_NAME}" chart/pulsar-mp \
    --namespace "${NAMESPACE}" \
    > "${APP_INSTANCE_NAME}_manifest.yaml"
```

#### Patch the manifest

We explicitly created the service accounts and RBAC resources above, so we need to modify the manifest to account for this.

```bash
./scripts/patch-manifest.sh "${APP_INSTANCE_NAME}"
```

This will replace default service account names and include common labels needed for the proper execution in the Google Cloud Marketplace environment.

#### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply all the resources to your Kubernetes cluster:

```bash
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" \
    --namespace "${NAMESPACE}" \
    --selector excluded-resource=no,is-crd=no
```

#### Wait for the Application components to become available

It will take about 10 or 15 minutes for all the components of Pulsar to become fully available and ready to use. You can follow the status of the install process with the following command:

```bash
watch kubectl get pods --namespace "$NAMESPACE"
```

OUTPUT:

```
NAME                                      READY   STATUS      RESTARTS   AGE
pulsar-mp-adminconsole-6dd85fdd66-lvvw2   2/2     Running     0          2m48s
pulsar-mp-autorecovery-85c888cbdf-7c554   1/1     Running     1          2m48s
pulsar-mp-bastion-8db47d6f6-9nnrt         1/1     Running     0          2m48s
pulsar-mp-bookkeeper-0                    1/1     Running     0          2m47s
pulsar-mp-broker-556d45d49-9ftsc          1/1     Running     0          2m48s
pulsar-mp-deployer-mhllh                  0/1     Completed   0          3m9s
pulsar-mp-proxy-769f4f867d-b5v7n          2/2     Running     0          2m48s
pulsar-mp-zookeeper-0                     1/1     Running     0          2m47s
pulsar-mp-zookeeper-metadata-l5wxr        0/1     Completed   0          2m47s
```

#### View the app in the Google Cloud Console

To get the GCP Console URL for your app, run the following command:

```bash
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${APP_INSTANCE_NAME}"
```

To view the app, open the URL in your browser.

# Uninstall the Application

## Using the Google Cloud Platform Console

1. In the GCP Console, open [Kubernetes Applications].
2. From the list of applications, click **pulsar-mp**.
3. On the Application Details page, click **Delete**.

## Using the command line

### Prepare the environment

Set your installation name and Kubernetes namespace:

```bash
export APP_INSTANCE_NAME=pulsar-mp
export NAMESPACE=default
```

### Delete the resources

Delete all the Application resources:

```bash
for resource_type in \
    application \
    clusterrole \
    clusterrolebinding \
    configmap \
    daemonset \
    deployment \
    job \
    mutatingwebhookconfiguration \
    persistentvolume \
    persistentvolumeclaim \
    pod \
    podsecuritypolicy \
    prometheus \
    prometheusrule \
    replicaset \
    role \
    rolebinding \
    secret \
    service \
    serviceaccount \
    servicemonitor \
    statefulset \
    validatingwebhookconfiguration; do

    kubectl delete "${resource_type}" \
        --selector app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
        --namespace "${NAMESPACE}"
done
```
