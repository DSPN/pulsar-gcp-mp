FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

COPY files/create_manifests.sh /bin/
COPY files/deploy.sh /bin/
COPY files/deploy_with_tests.sh /bin/
COPY files/get-service-account.sh /bin/
COPY files/labels_and_service_accounts_kustomize.yaml /app/
COPY files/excluded_resources_kustomize.yaml /app/
COPY files/crds_kustomize.yaml /app/
COPY files/kubesystem_kustomize.yaml /app/
COPY files/one-off-pods-kustomize.yaml /app/
COPY files/secrets-kustomize.yaml /app/
COPY files/billing-agent-kustomize.yaml /app/
COPY files/get-resource-name.py /app/

COPY 3rd-party /3rd-party

RUN /bin/bash -c 'chmod u+x /bin/get-service-account.sh'
RUN /bin/bash -c 'curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash; \
mv ./kustomize /bin/'

ENV WAIT_FOR_READY_TIMEOUT 1500
ENV TESTER_TIMEOUT 1500
