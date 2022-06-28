FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

# Upgrade to bionic to resolve CVE in expat package.
RUN apt-get update &&\
    apt-get -y install update-manager-core &&\
    do-release-upgrade -f DistUpgradeViewNonInteractive

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

RUN wget https://github.com/junit-team/junit4/archive/refs/tags/r4.13.2.tar.gz &&\
    tar xzvf r4.13.2.tar.gz &&\
    mv junit4-r4.13.2 /3rd-party/vendor/github.com/junit-team/junit4/junit4@r4.13.2 &&\
    rm r4.13.2.tar.gz

RUN wget https://github.com/javaee/javax.annotation/archive/refs/tags/1.3.2.tar.gz &&\
    tar xzvf 1.3.2.tar.gz &&\
    mv javax.annotation-1.3.2 /3rd-party/vendor/github.com/javaee/javax.annotations/javax.annotation-api@v1.3.2 &&\
    rm 1.3.2.tar.gz

RUN /bin/bash -c 'chmod u+x /bin/get-service-account.sh'
RUN /bin/bash -c 'curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash; \
mv ./kustomize /bin/'

ENV WAIT_FOR_READY_TIMEOUT 1500
ENV TESTER_TIMEOUT 1500
