#!/bin/bash

CWD=$(pwd)
IMMUDB_RELEASE_NAME="immudb"
IMMUDB_NAMESPACE="codenotary"

echo "---------------------- 0. checking dependencies ----------------------"
for executable in terraform ansible-playbook helm; do
    if ! command -v $executable &> /dev/null
    then
        echo "$executable missing"
        exit
    fi
done
echo "check for dependencies successfully finished"

echo "--------------------------- 1. setup infra ---------------------------"
cd $CWD/tf
terraform init
terraform apply

NODE_IP=$(cat $CWD/tf/terraform.tfstate | jq --raw-output '.outputs["IPAddress"]["value"] //empty')

if [[ -z "$NODE_IP" ]]
then
      echo "No IP assigned to the node! Aborting.."
      exit
else
    # update ansible hosts file (as we have only one it is always on the second line)
    sed -i '2s/.*/'$NODE_IP'/' $CWD/ansible/hosts
fi
echo "infra setup successfully finished. node with $NODE_IP is online"

echo "-------------------------- 2. setup cluster --------------------------"
cd $CWD/ansible
ansible-playbook bootstrap.yml
ansible-playbook k8s.yml

KUBECONFIG_PATH=$CWD/ansible/kubeconfig/$NODE_IP/home/vagrant/config

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "Failed to locate kubeconfig. Aborting.."
    exit
fi

chmod 600 KUBECONFIG_PATH
export KUBECONFIG=$KUBECONFIG_PATH

echo "--------------------------- 3. install apps ---------------------------"
cd $CWD/helm

# install immudb primary
helm upgrade \
    --install \
    --namespace $IMMUDB_NAMESPACE \
    --create-namespace \
    --set volume.class="local-storage" \
    --set ingress.enabled=true \
    --set ingress.className=nginx \
    --set ingress.tls.enabled=true \
    --debug \
    $IMMUDB_RELEASE_NAME ./immudb/helm/

kubectl -n $IMMUDB_NAMESPACE wait pods $IMMUDB_RELEASE_NAME-0 --for condition=Ready --timeout=120s

# install immudb replica
helm upgrade \
    --install \
    --namespace $IMMUDB_NAMESPACE \
    --set volume.class="local-storage" \
    --set replication.replicationIsReplica=true \
    --set replication.replicationPrimaryHost=immudb-http.$IMMUDB_NAMESPACE.svc.cluster.local \
    --set replication.replicationPrimaryUsername=immudb \
    --set replication.replicationPrimaryPassword=immudb \
    --debug \
    $IMMUDB_RELEASE_NAME-replica ./immudb/helm/

kubectl -n $IMMUDB_NAMESPACE wait pods $IMMUDB_RELEASE_NAME-replica-0 --for condition=Ready --timeout=120s

# install ingress
helm upgrade \
    --install \
    --namespace $IMMUDB_NAMESPACE \
    --set controller.service.loadBalancerIP=$NODE_IP \
    nginx-ingress nginx-stable/nginx-ingress --set rbac.create=true

# install metrics services
kubectl -n $IMMUDB_NAMESPACE apply -f pv-grafana.yaml
helm upgrade \
    --install \
    --namespace $IMMUDB_NAMESPACE \
    --set persistence.storageClass=local-storage \
    grafana bitnami/grafana

kubectl -n $IMMUDB_NAMESPACE apply -f pv-prometheus-server.yaml
helm install \
    --namespace $IMMUDB_NAMESPACE \
    --set persistentVolume.storageClass=local-storage \
    prometheus ./prometheus/charts/prometheus/
