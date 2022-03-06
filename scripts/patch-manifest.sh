#!/bin/bash

set -eox pipefail

work_dir="$(mktemp -d)"

on_exit() {

    code=$?

    if [ -d "${work_dir}" ]; then
        (
            cd "${work_dir}" && rm -rf *
        )
        rmdir "${work_dir}"
    fi

  exit ${code}
}

trap "on_exit" EXIT

app_instance_name="$1"

if [ -z "${app_instance_name}" ]; then
    echo "app_instance_name is required"
    exit 1
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
chart_file_name="${app_instance_name}_manifest.yaml"

cd "${work_dir}"

cp "${script_dir}"/../"${app_instance_name}_manifest.yaml" .

sed -i "s|fullname-override-template-placeholder|$NAME|g" "${app_instance_name}_manifest.yaml"

KUBE_PROM_NAME="$(grep -E '^.*name: .*-kube-.*-operator$' ${app_instance_name}_manifest.yaml | tail -n1 | awk -F ' ' '{print $2}')"
KUBE_PROM_NAME="${KUBE_PROM_NAME#${NAME}-}"
KUBE_PROM_NAME="${KUBE_PROM_NAME%-operator}"
export KUBE_PROM_NAME

CHART_FILE_NAME=${chart_file_name} envsubst \
    < "${script_dir}"/../files/labels_and_service_accounts_kustomize.yaml \
    > ./kustomization.yaml
kustomize build . > ./chart-kustomized.yaml

CHART_FILE_NAME=chart-kustomized.yaml envsubst \
    < "${script_dir}"/../files/excluded_resources_kustomize.yaml \
    > ./kustomization.yaml
kustomize build . > ./chart-kustomized2.yaml

CHART_FILE_NAME=chart-kustomized2.yaml envsubst \
    < "${script_dir}"/../files/kubesystem_kustomize.yaml \
    > ./kustomization.yaml
kustomize build . > ./chart-kustomized3.yaml

CHART_FILE_NAME=chart-kustomized3.yaml envsubst \
    < "${script_dir}"/../files/one-off-pods-kustomize.yaml \
    > ./kustomization.yaml
kustomize build . > ./chart-kustomized4.yaml

CHART_FILE_NAME=chart-kustomized4.yaml envsubst \
    < "${script_dir}"/../files/secrets-kustomize.yaml \
    > ./kustomization.yaml
kustomize build . > ./chart-kustomized5.yaml

CHART_FILE_NAME=chart-kustomized5.yaml envsubst \
    < "${script_dir}"/../files/crds_kustomize.yaml \
    > ./kustomization.yaml

kustomize build . > "${script_dir}"/../${chart_file_name}

