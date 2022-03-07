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
export NAME="${app_instance_name}"

if [ -z "${app_instance_name}" ]; then
    echo "app_instance_name is required"
    exit 1
fi

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
chart_file_name="${app_instance_name}_manifest.yaml"

cd "${work_dir}"

cp "${script_dir}"/../"${app_instance_name}_manifest.yaml" .

sed -i.bak "s|fullname-override-template-placeholder|$app_instance_name|g" "${chart_file_name}"

if which python3; then
    PYTHON=python3
elif which python2; then
    PYTHON=python2
else
    PYTHON=python
fi

# Fix duplicate initContainers key in autorecovery-deployment.yaml
$PYTHON << END
target_yaml = False
target_section = False
processed = False
with open('manifest.yaml', 'w', encoding='utf-8') as out:
    with open('${chart_file_name}', 'r', encoding='utf-8') as f:
        for line in f:
            if processed:
                out.write(line)
                continue
            if 'autorecovery-deployment.yaml' in line:
                target_yaml = True
            if target_yaml and not target_section and 'initContainers' in line:
                target_section = True
                continue
            if target_section and 'initContainers' in line:
                target_section = False
                processed = True
            if not target_section:
                out.write(line)
END

mv manifest.yaml ${chart_file_name}

# Fix duplicate functionWorkerWebServiceURL key in proxy-configmap.yaml
$PYTHON << END
target_yaml = False
processed = False
with open('manifest.yaml', 'w', encoding='utf-8') as out:
    with open('${chart_file_name}', 'r', encoding='utf-8') as f:
        for line in f:
            if 'proxy-configmap.yaml' in line:
                target_yaml = True
            if target_yaml and 'functionWorkerWebServiceURL' in line and not processed:
                processed = True
                continue
            out.write(line)
END

mv manifest.yaml ${chart_file_name}

KUBE_PROM_NAME="$(grep -E '^.*name: .*-kube-.*-operator$' ${chart_file_name} | tail -n1 | awk -F ' ' '{print $2}')"
KUBE_PROM_NAME="${KUBE_PROM_NAME#${NAME}-}"
KUBE_PROM_NAME="${KUBE_PROM_NAME%-operator}"
export KUBE_PROM_NAME

CHART_FILE_NAME=${chart_file_name} envsubst \
    < "${script_dir}"/../files/labels_and_service_accounts_kustomize.yaml \
    > ./kustomization.yaml
kustomize --stack-trace build . > ./chart-kustomized.yaml

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

kustomize build . > "${chart_file_name}"

openssl req -x509 \
    -sha256 \
    -newkey rsa:2048 \
    -keyout tls.key \
    -out tls.crt \
    -days 18250 \
    -nodes \
    -subj "/C=US/ST=CA/L=NA/O=IT/CN=$NAME.$NAMESPACE"
cat tls.key | base64 -w 0 > tlsb64e.key 2>/dev/null || cat tls.key | base64 > tlsb64e.key
cat tls.crt | base64 -w 0 > tlsb64e.crt 2>/dev/null || cat tls.crt | base64 > tlsb64e.crt

sed -r -i.bak "s|^  tls.key:.*$|  tls.key: $(cat tlsb64e.key)|" "${chart_file_name}"
sed -r -i.bak "s|^  tls.crt:.*$|  tls.crt: $(cat tlsb64e.crt)|" "${chart_file_name}"
sed -r -i.bak "s|^  ca.crt:.*$|  ca.crt: $(cat tlsb64e.crt)|" "${chart_file_name}"

mv "${chart_file_name}" "${script_dir}"/../${chart_file_name}
