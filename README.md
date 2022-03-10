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
export ZONE=us-west1-a
export RELEASE_CHANNEL=rapid
gcloud container clusters create "${CLUSTER}" \
    --zone "$ZONE" \
    --release-channel "$RELEASE_CHANNEL" \
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
export NAMESPACE=pulsar-mp
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
export IMAGE_ADMIN_CONSOLE="admin-console"
export IMAGE_ADMIN_CONSOLE_NGINX="admin-console-nginx"
export IMAGE_BASTION="bastion"
export IMAGE_BEAM="beam"
export IMAGE_BOOKKEEPER="bookkeeper"
export IMAGE_BROKER="broker"
export IMAGE_BROKER_STS="broker-sts"
export IMAGE_BURNELL="burnell"
export IMAGE_BURNELL_LOG_COLLECTOR="burnell-log-collector"
export IMAGE_FUNCTION="function"
export IMAGE_GRAFANA="grafana"
export IMAGE_GRAFANA_SIDECAR="grafana-sidecar"
export IMAGE_HEARTBEAT="heartbeat"
export IMAGE_KUBE_STATE_METRICS="kube-state-metrics"
export IMAGE_PROMETHEUS="prometheus"
export IMAGE_PROMETHEUS_NODE_EXPORTER="prometheus-node-exporter"
export IMAGE_PROMETHEUS_OPERATOR="prometheus-operator"
export IMAGE_PROMETHEUS_OPERATOR_ADMISSION_PATCH="prometheus-operator-admission-patch"
export IMAGE_PROMETHEUS_OPERATOR_CONFIGMAP_RELOAD="prometheus-operator-configmap-reload"
export IMAGE_PROMETHEUS_OPERATOR_CONFIG_RELOADER="prometheus-operator-config-reloader"
export IMAGE_PROXY="proxy"
export IMAGE_SQL="sql"
export IMAGE_TARDIGRADE="tardigrade"
export IMAGE_ZOOKEEPER="zookeeper"
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
  type: pd-ssd
  fstype: ext4
  replication-type: none
EOF
```

#### Create the namespace in your Kubernetes cluster

If you use a namespace other than the `default`, run the command below to create a new namespace.

```bash
kubectl create namespace "${NAMESPACE}"
```

#### Create service accounts and RBAC resources for each of the Pulsar components

##### burnell

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-burnellserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-burnellserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

#role:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/name: ${NAMESPACE}
  name: ${APP_INSTANCE_NAME}:burnellServiceAccount
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - create
  - list
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - list
- apiGroups:
  - "apps"
  resources:
  - deployments
  - statefulsets
  verbs:
  - list

EOF

#rolebinding:
kubectl create rolebinding "${APP_INSTANCE_NAME}:burnellServiceAccount" \
    --namespace="${NAMESPACE}" \
    --role="${APP_INSTANCE_NAME}:burnellServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-burnellserviceaccount"
kubectl label rolebindings "${APP_INSTANCE_NAME}:burnellServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### function

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-functionserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-functionserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

#role:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/name: ${NAMESPACE}
  name: ${APP_INSTANCE_NAME}:functionServiceAccount
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - "*"
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - get
  - create
  - delete
- apiGroups:
  - "apps"
  resources:
  - statefulsets
  verbs:
  - get
  - create
  - delete
EOF

#rolebinding:
kubectl create rolebinding "${APP_INSTANCE_NAME}:functionServiceAccount" \
    --namespace="${NAMESPACE}" \
    --role="${APP_INSTANCE_NAME}:functionServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-functionserviceaccount"
kubectl label rolebindings "${APP_INSTANCE_NAME}:functionServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### pulsarheartbeat

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-pulsarheartbeatserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-pulsarheartbeatserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

#role:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/name: ${NAMESPACE}
  name: ${APP_INSTANCE_NAME}:pulsarheartbeatServiceAccount
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
- apiGroups:
  - "apps"
  resources:
  - deployment
  - statefulsets
  verbs:
  - list
EOF

#rolebinding:
kubectl create rolebinding "${APP_INSTANCE_NAME}:pulsarheartbeatServiceAccount" \
    --namespace="${NAMESPACE}" \
    --role="${APP_INSTANCE_NAME}:pulsarheartbeatServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-pulsarheartbeatserviceaccount"
kubectl label rolebindings "${APP_INSTANCE_NAME}:pulsarheartbeatServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### grafana

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-grafanaserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-grafanaserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

#role:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/name: ${NAMESPACE}
  name: ${APP_INSTANCE_NAME}:grafanaServiceAccount
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - "extensions"
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF

#rolebinding:
kubectl create rolebinding "${APP_INSTANCE_NAME}:grafanaServiceAccount" \
    --namespace="${NAMESPACE}" \
    --role="${APP_INSTANCE_NAME}:grafanaServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-grafanaserviceaccount"
kubectl label rolebindings "${APP_INSTANCE_NAME}:grafanaServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:grafanaServiceAccount"
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - get
  - watch
  - list
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:grafanaServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:grafanaServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-grafanaserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:grafanaServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### kube-prometheus-admission

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-kube-prometheus-admissionserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-kube-prometheus-admissionserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

#role:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/name: ${NAMESPACE}
  name: ${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount
  namespace: ${NAMESPACE}
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - create
EOF

#rolebinding:
kubectl create rolebinding "${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" \
    --namespace="${NAMESPACE}" \
    --role="${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-kube-prometheus-admissionserviceaccount"
kubectl label rolebindings "${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount"
rules:
- apiGroups:
  - "admissionregistration.k8s.io"
  resources:
  - validatingwebhookconfigurations
  - mutatingwebhookconfigurations
  verbs:
  - get
  - update
- apiGroups:
  - "policy"
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-kube-prometheus-admissionserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:kube-prometheus-admissionServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### kube-prometheus-operator

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-kube-prometheus-operatorserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-kube-prometheus-operatorserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:kube-prometheus-operatorServiceAccount"
rules:
- apiGroups:
  - "admissionregistration.k8s.io"
  resources:
  - validatingwebhookconfigurations
  - mutatingwebhookconfigurations
  verbs:
  - get
  - update
- apiGroups:
  - "policy"
  resources:
  - podsecuritypolicies
  verbs:
  - use

- apiGroups:
  - monitoring.coreos.com
  resources:
  - alertmanagers
  - alertmanagers/finalizers
  - alertmanagerconfigs
  - prometheuses
  - prometheuses/finalizers
  - thanosrulers
  - thanosrulers/finalizers
  - servicemonitors
  - podmonitors
  - probes
  - prometheusrules
  verbs:
  - "*"
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - "*"
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  verbs:
  - "*"
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
  - delete
- apiGroups:
  - ""
  resources:
  - services
  - services/finalizers
  - endpoints
  verbs:
  - get
  - create
  - update
  - delete
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - "networking.k8s.io"
  resources:
  - ingress
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - "policy"
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:kube-prometheus-operatorServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:kube-prometheus-operatorServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-kube-prometheus-operatorserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:kube-prometheus-operatorServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### kube-prometheus-prometheus

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-kube-prometheus-prometheusserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-kube-prometheus-prometheusserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:kube-prometheus-prometheusServiceAccount"
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingress
  verbs:
  - get
  - watch
  - list
- apiGroups:
  - policy
  resources:
  - podsecuritypolicies
  verbs:
  - use

- apiGroups:
  - ""
  resources:
  - validatingwebhookconfigurations
  - mutatingwebhookconfigurations
  verbs:
  - get
  - update
- apiGroups:
  - "policy"
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:kube-prometheus-prometheusServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:kube-prometheus-prometheusServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-kube-prometheus-prometheusserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:kube-prometheus-prometheusServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### kube-state-metrics

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-kube-state-metricsserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-kube-state-metricsserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:kube-state-metricsServiceAccount"
rules:
- apiGroups:
  - policy
  resources:
  - podsecuritypolicies
  verbs:
  - use
- apiGroups:
  - certificates.k8s.io
  resources:
  - certificatesigningrequests
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  - apps
  resources:
  - daemonsets
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  - apps
  resources:
  - deployments
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - endpoints
  verbs:
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - jobs
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - limitranges
  verbs:
  - list
  - watch
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - mutatingwebhookconfigurations
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - networkpolicies
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - persistentvolumeclaims
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - persistentvolumes
  verbs:
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  - apps
  resources:
  - replicasets
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - replicationcontrollers
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - resourcequotas
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - storageclasses
  verbs:
  - list
  - watch
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - validatingwebhookconfigurations
  verbs:
  - list
  - watch
- apiGroups:
  - storage.k8s.io
  resources:
  - volumeattachments
  verbs:
  - list
  - watch
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:kube-state-metricsServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:kube-state-metricsServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-kube-state-metricsserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:kube-state-metricsServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

##### prometheus-node-exporter

```bash
#service account:
kubectl create serviceaccount "${APP_INSTANCE_NAME}-prometheus-node-exporterserviceaccount" \
    --namespace="${NAMESPACE}"
kubectl label serviceaccounts "${APP_INSTANCE_NAME}-prometheus-node-exporterserviceaccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"

# clusterrole:
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: ${APP_INSTANCE_NAME}
  name: "${APP_INSTANCE_NAME}:prometheus-node-exporterServiceAccount"
rules:
- apiGroups:
  - "extensions"
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF

# clusterrolebinding:
kubectl create clusterrolebinding "${APP_INSTANCE_NAME}:prometheus-node-exporterServiceAccount" \
    --namespace="${NAMESPACE}" \
    --clusterrole="${APP_INSTANCE_NAME}:prometheus-node-exporterServiceAccount" \
    --serviceaccount="${NAMESPACE}:${APP_INSTANCE_NAME}-prometheus-node-exporterserviceaccount"
kubectl label clusterrolebindings "${APP_INSTANCE_NAME}:prometheus-node-exporterServiceAccount" app.kubernetes.io/name="${APP_INSTANCE_NAME}" \
    --namespace="${NAMESPACE}"
```

#### Expand the manifest template

Use `helm template` to expand the template. We recommend that you save the expanded manifest file for future updates to the application.

```bash
helm template "${APP_INSTANCE_NAME}" chart/pulsar-mp \
    --namespace "${NAMESPACE}" \
    --include-crds \
    --set pulsar.image.broker.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BROKER}" \
    --set pulsar.image.broker.tag="$TAG" \
    --set pulsar.image.brokerSts.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BROKER_STS}" \
    --set pulsar.image.brokerSts.tag="$TAG" \
    --set pulsar.image.function.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_FUNCTION}" \
    --set pulsar.image.function.tag="$TAG" \
    --set pulsar.image.zookeeper.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_ZOOKEEPER}" \
    --set pulsar.image.zookeeper.tag="$TAG" \
    --set pulsar.image.bookkeeper.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BOOKKEEPER}" \
    --set pulsar.image.bookkeeper.tag="$TAG" \
    --set pulsar.image.proxy.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROXY}" \
    --set pulsar.image.proxy.tag="$TAG" \
    --set pulsar.image.bastion.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BASTION}" \
    --set pulsar.image.bastion.tag="$TAG" \
    --set pulsar.image.pulsarBeam.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BEAM}" \
    --set pulsar.image.pulsarBeam.tag="$TAG" \
    --set pulsar.image.burnell.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BURNELL}" \
    --set pulsar.image.burnell.tag="$TAG" \
    --set pulsar.image.burnellLogCollector.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_BURNELL_LOG_COLLECTOR}" \
    --set pulsar.image.burnellLogCollector.tag="$TAG" \
    --set pulsar.image.pulsarSQL.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_SQL}" \
    --set pulsar.image.pulsarSQL.tag="$TAG" \
    --set pulsar.image.tardigrade.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_TARDIGRADE}" \
    --set pulsar.image.tardigrade.tag="$TAG" \
    --set pulsar.image.pulsarHeartbeat.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_HEARTBEAT}" \
    --set pulsar.image.pulsarHeartbeat.tag="$TAG" \
    --set pulsar.image.pulsarAdminConsole.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_ADMIN_CONSOLE}" \
    --set pulsar.image.pulsarAdminConsole.tag="$TAG" \
    --set pulsar.image.pulsarAdminConsoleNginx.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_ADMIN_CONSOLE_NGINX}" \
    --set pulsar.image.pulsarAdminConsoleNginx.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheus.prometheusSpec.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS}" \
    --set pulsar.kube-prometheus-stack.prometheus.prometheusSpec.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheus-node-exporter.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS_NODE_EXPORTER}" \
    --set pulsar.kube-prometheus-stack.prometheus-node-exporter.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS_OPERATOR}" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.admissionWebhooks.patch.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS_OPERATOR_ADMISSION_PATCH}" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.admissionWebhooks.patch.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.configmapReloadImage.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS_OPERATOR_CONFIG_RELOAD}" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.configmapReloadImage.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.prometheusConfigReloaderImage.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_PROMETHEUS_OPERATOR_CONFIG_RELOADER}" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.prometheusConfigReloaderImage.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.kube-state-metrics.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_KUBE_STATE_METRICS}" \
    --set pulsar.kube-prometheus-stack.kube-state-metrics.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.grafana.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_GRAFANA}" \
    --set pulsar.kube-prometheus-stack.grafana.image.tag="$TAG" \
    --set pulsar.kube-prometheus-stack.grafana.sidecar.image.repository="${REGISTRY}/${REPOSITORY}/${IMAGE_GRAFANA}" \
    --set pulsar.kube-prometheus-stack.grafana.sidecar.image.tag="$TAG" \
    --set pulsar.fullnameOverride="fullname-override-template-placeholder" \
    --set pulsar.enableAntiAffinity="false" \
    --set pulsar.enableTls="true" \
    --set pulsar.tlsSecretName="pulsar-mp-tls" \
    --set pulsar.enableTokenAuth="true" \
    --set pulsar.secrets.key="pulsar-mp-tls-key-placeholder" \
    --set pulsar.secrets.certificate="pulsar-mp-tls-certificate-placeholder" \
    --set pulsar.secrets.caCertificate="pulsar-mp-tls-ca-certificate-placeholder" \
    --set pulsar.restartOnConfigMapChange.enabled="true" \
    --set pulsar.extra.function="true" \
    --set pulsar.extra.burnell="true" \
    --set pulsar.extra.burnellLogCollector="true" \
    --set pulsar.extra.pulsarHeartbeat="true" \
    --set pulsar.extra.pulsarAdminConsole="true" \
    --set pulsar.default_storage.existingStorageClassName="pulsar-storage" \
    --set pulsar.cert-manager.enabled="false" \
    --set pulsar.createCertificates.selfSigned.enabled="false" \
    --set pulsar.zookeeper.replicaCount="1" \
    --set pulsar.zookeeper.resources.requests.memory="300Mi" \
    --set pulsar.zookeeper.resources.requests.cpu="0.3" \
    --set pulsar.zookeeper.configData.PULSAR_MEM="-Xms300m -Xmx300m -Djute.maxbuffer=10485760 -XX:+ExitOnOutOfMemoryError" \
    --set pulsar.bookkeeper.replicaCount="1" \
    --set pulsar.bookkeeper.resources.requests.memory="512Mi" \
    --set pulsar.bookkeeper.resources.requests.cpu="0.3" \
    --set pulsar.bookkeeper.configData.BOOKIE_MEM="-Xms312m -Xmx312m -XX:MaxDirectMemorySize=200m -XX:+ExitOnOutOfMemoryError" \
    --set pulsar.broker.component="broker" \
    --set pulsar.broker.replicaCount="1" \
    --set pulsar.broker.ledger.defaultEnsembleSize="1" \
    --set pulsar.broker.ledger.defaultAckQuorum="1" \
    --set pulsar.broker.ledger.defaultWriteQuorum="1" \
    --set pulsar.broker.resources.requests.memory="600Mi" \
    --set pulsar.broker.resources.requests.cpu="0.3" \
    --set pulsar.broker.configData.PULSAR_MEM="-Xms400m -Xmx400m -XX:MaxDirectMemorySize=200m -XX:+ExitOnOutOfMemoryError" \
    --set pulsar.autoRecovery.enableProvisionContainer="true" \
    --set pulsar.autoRecovery.resources.requests.memory="300Mi" \
    --set pulsar.autoRecovery.resources.requests.cpu="0.3" \
    --set pulsar.function.replicaCount="1" \
    --set pulsar.function.functionReplicaCount="1" \
    --set pulsar.function.resources.requests.memory="512Mi" \
    --set pulsar.function.resources.requests.cpu="0.3" \
    --set pulsar.function.configData.PULSAR_MEM="-Xms312m -Xmx312m -XX:MaxDirectMemorySize=200m -XX:+ExitOnOutOfMemoryError" \
    --set pulsar.proxy.replicaCount="1" \
    --set pulsar.proxy.resources.requests.memory="512Mi" \
    --set pulsar.proxy.resources.requests.cpu="0.3" \
    --set pulsar.proxy.wsResources.requests.memory="512Mi" \
    --set pulsar.proxy.wsResources.requests.cpu="0.3" \
    --set pulsar.proxy.configData.PULSAR_MEM="-Xms400m -Xmx400m -XX:MaxDirectMemorySize=112m" \
    --set pulsar.proxy.autoPortAssign.enablePlainTextWithTLS="true" \
    --set pulsar.proxy.service.autoPortAssign.enabled="true" \
    --set pulsar.grafanaDashboards.enabled="true" \
    --set pulsar.pulsarAdminConsole.replicaCount="1" \
    --set pulsar.pulsarAdminConsole.authMode="k8s" \
    --set pulsar.pulsarAdminConsole.createUserSecret.enabled="true" \
    --set pulsar.pulsarAdminConsole.createUserSecret.user="admin" \
    --set pulsar.pulsarAdminConsole.createUserSecret.password="e9JYtk83*4#PM8" \
    --set pulsar.kube-prometheus-stack.enabled="true" \
    --set pulsar.kube-prometheus-stack.prometheusOperator.enabled="true" \
    --set pulsar.kube-prometheus-stack.grafana.enabled="true" \
    --set pulsar.kube-prometheus-stack.grafana.adminPassword="password" \
    > "${APP_INSTANCE_NAME}_manifest.yaml"
```

#### Patch the manifest as needed

We explicitly created the service accounts and RBAC resources above, so we need to modify the manifest to account for this.

```bash
./scripts/patch-manifest.sh "${APP_INSTANCE_NAME}"
```

This will replace default service account names and include common labels needed for the proper execution in the Google Cloud Marketplace environment. It will also create the necessary certificates and keys for TLS support.

#### Apply the manifest to your Kubernetes cluster

First use `kubectl` to apply the CustomResourceDefinitions to your Kubernetes cluster:

```bash
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" \
              --namespace="$NAMESPACE" \
              --selector is-crd=yes || true

sleep 5

# We need to apply a second time here to work-around resource order of creation issues.
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" \
              --namespace="$NAMESPACE" \
              --selector is-crd=yes || true

sleep 10
```

Next, use `kubectl` to apply the non-kube-system namespace resources to your Kubernetes cluster:

```bash
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" \
              --namespace "${NAMESPACE}" \
              --selector is-crd=no,excluded-resource=no,requires-kube-system-namespace=no
```

Lastly, apply the resources that require the kube-system namespace to be specified:

```bash
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" \
              --namespace="kube-system" \
              --selector is-crd=no,excluded-resource=no,requires-kube-system-namespace=yes
```

#### Wait for the Application components to become available

It will take about 10 or 15 minutes for all the components of Pulsar to become fully available and ready to use. You can follow the status of the install process with the following command:

```bash
watch kubectl get pods --namespace "$NAMESPACE"
```

OUTPUT:

```
NAME                                                  READY   STATUS      RESTARTS        AGE
prometheus-pulsar-mp-kube-prometheus-prometheus-0     2/2     Running     1 (90s ago)     95s
pulsar-mp-adminconsole-6df4945944-5844x               2/2     Running     0               3m53s
pulsar-mp-autorecovery-56f8bf75fb-lg6qq               1/1     Running     1 (2m36s ago)   3m53s
pulsar-mp-bastion-5dc7665c7f-whrxc                    1/1     Running     0               3m52s
pulsar-mp-bookkeeper-0                                1/1     Running     0               3m49s
pulsar-mp-broker-69df6fcf-hkxnx                       1/1     Running     0               3m52s
pulsar-mp-function-0                                  2/2     Running     0               3m49s
pulsar-mp-grafana-774d986ff4-pwff4                    0/2     Init:0/1    0               3m52s
pulsar-mp-kube-prometheus-admission-create--1-hkjzs   0/1     Completed   0               3m45s
pulsar-mp-kube-prometheus-admission-patch--1-mxfv4    0/1     Completed   0               3m45s
pulsar-mp-kube-prometheus-operator-84cd476fd5-hdtk4   1/1     Running     0               3m51s
pulsar-mp-kube-state-metrics-6c996bb7b8-rwsvj         1/1     Running     0               3m51s
pulsar-mp-prometheus-node-exporter-dl6mc              1/1     Running     0               3m46s
pulsar-mp-prometheus-node-exporter-jz67b              1/1     Running     0               3m46s
pulsar-mp-prometheus-node-exporter-tbp78              1/1     Running     0               3m46s
pulsar-mp-proxy-6d9f8fd546-rq672                      3/3     Running     0               3m50s
pulsar-mp-pulsarheartbeat-6fc5596f59-66hpf            1/1     Running     0               3m50s
pulsar-mp-zookeeper-0                                 1/1     Running     0               3m48s
pulsar-mp-zookeeper-metadata--1-cb2zg                 0/1     Completed   0               3m45s
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
