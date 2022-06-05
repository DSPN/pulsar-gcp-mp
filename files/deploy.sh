#!/bin/bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eox pipefail

# This is the entry point for the production deployment

# If any command returns with non-zero exit code, set -e will cause the script
# to exit. Prior to exit, set App assembly status to "Failed".
handle_failure() {
  code=$?
  if [[ -z "$NAME" ]] || [[ -z "$NAMESPACE" ]]; then
    # /bin/expand_config.py might have failed.
    # We fall back to the unexpanded params to get the name and namespace.
    NAME="$(/bin/print_config.py \
            --xtype NAME \
            --values_mode raw)"
    NAMESPACE="$(/bin/print_config.py \
            --xtype NAMESPACE \
            --values_mode raw)"
    export NAME
    export NAMESPACE
  fi
  patch_assembly_phase.sh --status="Failed"
  exit $code
}
trap "handle_failure" EXIT

NAME="$(/bin/print_config.py \
    --xtype NAME \
    --values_mode raw)"
NAMESPACE="$(/bin/print_config.py \
    --xtype NAMESPACE \
    --values_mode raw)"
export NAME
export NAMESPACE

echo "Deploying application \"$NAME\""

app_uid=$(kubectl get "applications.app.k8s.io/$NAME" \
  --namespace="$NAMESPACE" \
  --output=jsonpath='{.metadata.uid}')
app_api_version=$(kubectl get "applications.app.k8s.io/$NAME" \
  --namespace="$NAMESPACE" \
  --output=jsonpath='{.apiVersion}')

/bin/expand_config.py --values_mode raw --app_uid "$app_uid"

create_manifests.sh

sed -i "s|fullname-override-template-placeholder|$NAME|g" /data/manifest-expanded/chart.yaml

export WEBHOOK_ADMISS_SA="$(get-service-account.sh 'webhook-admiss-sa')"
export GRAFANA_SA="$(get-service-account.sh 'grafana-sa')"
export PROM_OPERATOR_SA="$(get-service-account.sh 'prom-operator-sa')"
export PROMETHEUS_SA="$(get-service-account.sh 'prometheus-sa')"
export BURNELL_SA="$(get-service-account.sh 'burnell-sa')"
export FUNCTION_SA="$(get-service-account.sh 'function-sa')"
export KUBE_STATE_METRICS_SA="$(get-service-account.sh 'kube-state-metrics-sa')"
export PROM_NODE_EXPORTER_SA="$(get-service-account.sh 'prom-node-exporter-sa')"
export PULSAR_HEARTBEAT_SA="$(get-service-account.sh 'pulsar-heartbeat-sa')"

export WEBHOOK_ADMISS_CREATE_JOB="$(/usr/bin/env python3 /app/get-resource-name.py 'admiss-create')"
export WEBHOOK_ADMISS_PATCH_JOB="$(/usr/bin/env python3 /app/get-resource-name.py 'admiss-patch')"
export GRAFANA_DEPLOYMENT="$(/usr/bin/env python3 /app/get-resource-name.py 'grafana')"
export PROM_OPERATOR_DEPLOYMENT="$(/usr/bin/env python3 /app/get-resource-name.py 'prom-operator')"
export PROMETHEUS_DEPLOYMENT="$(/usr/bin/env python3 /app/get-resource-name.py 'prometheus')"
export KUBE_STATE_METRICS_DEPLOYMENT="$(/usr/bin/env python3 /app/get-resource-name.py 'kube-state-metrics')"
export PULSAR_HEARTBEAT_DEPLOYMENT="$(/usr/bin/env python3 /app/get-resource-name.py 'pulsar-heartbeat')"

export PROM_NAME="${PROMETHEUS_DEPLOYMENT%%-prometheus}"
echo "$PROM_NAME"

export UBBAGENT_IMAGE="$(grep '^ubbagent-image-repository:' /data/final_values.yaml | awk -F ' ' '{print $2}')"
export REPORTING_SECRET="$(grep '^reportingSecret:' /data/final_values.yaml | awk -F ' ' '{print $2}')"

random_string() {
   set +o pipefail
   strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 12 | tr -d '\n' | base64 -w 0
   set -o pipefail
}

GRAFANA_ADMIN_PASSWORD="$(random_string)"
DASHBOARD_USER_ADMIN_PASSWORD="$(random_string)"
export GRAFANA_ADMIN_PASSWORD
export DASHBOARD_USER_ADMIN_PASSWORD

envsubst \
    < /app/labels_and_service_accounts_kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/excluded_resources_kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/kubesystem_kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/one-off-pods-kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/secrets-kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/crds_kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

envsubst \
    < /app/billing-agent-kustomize.yaml \
    > /data/manifest-expanded/kustomization.yaml
kustomize build /data/manifest-expanded > /data/manifest-expanded/chart-kustomized.yaml
mv /data/manifest-expanded/chart-kustomized.yaml /data/manifest-expanded/chart.yaml

rm /data/manifest-expanded/kustomization.yaml

# Create TLS cert and secret
openssl req -x509 \
    -sha256 \
    -newkey rsa:2048 \
    -keyout /app/tls.key \
    -out /app/tls.crt \
    -days 18250 \
    -nodes \
    -subj "/C=US/ST=CA/L=NA/O=IT/CN=$NAME-broker.$NAMESPACE.svc.cluster.local"
cat /app/tls.key | base64 -w 0 > /app/tlsb64e.key
cat /app/tls.crt | base64 -w 0 > /app/tlsb64e.crt

sed -r -i "s|(^ *?tls.key:).*$|\1 $(cat /app/tlsb64e.key)|" /data/manifest-expanded/chart.yaml
sed -r -i "s|(^ *?tls.crt:).*$|\1 $(cat /app/tlsb64e.crt)|" /data/manifest-expanded/chart.yaml
sed -r -i "s|(^ *?ca.crt:).*$|\1 $(cat /app/tlsb64e.crt)|" /data/manifest-expanded/chart.yaml

# Assign owner references for the resources.
/bin/set_ownership.py \
  --app_name "$NAME" \
  --app_uid "$app_uid" \
  --app_api_version "$app_api_version" \
  --manifests "/data/manifest-expanded" \
  --dest "/data/resources.yaml"

validate_app_resource.py --manifests "/data/resources.yaml"

# Ensure assembly phase is "Pending", until successful kubectl apply.
/bin/setassemblyphase.py \
  --manifest "/data/resources.yaml" \
  --status "Pending"

# Apply the manifest.
kubectl apply --namespace="$NAMESPACE" \
              --filename="/data/resources.yaml" \
              --selector is-crd=yes || true

sleep 10

# Now apply the other non crd resources.
kubectl apply  --namespace="$NAMESPACE" \
               --filename="/data/resources.yaml" \
               --selector is-crd=no,excluded-resource=no,requires-kube-system-namespace=no

# Lastly, apply the resources that require the kube-system namespace to be specified.
kubectl apply  --namespace="kube-system" \
               --filename="/data/resources.yaml" \
               --selector is-crd=no,excluded-resource=no,requires-kube-system-namespace=yes

patch_assembly_phase.sh --status="Success"

wait_for_ready.py \
  --name $NAME \
  --namespace $NAMESPACE \
  --timeout ${WAIT_FOR_READY_TIMEOUT:-1500}

clean_iam_resources.sh

trap - EXIT
