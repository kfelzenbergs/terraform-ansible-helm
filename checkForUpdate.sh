#!/bin/bash

helm repo update
VERSION_LATEST=$(helm search repo immudb/immudb | awk '{print $2}' | tail -n 1)
VERSION_CURRENT=$(helm --namespace codenotary show chart helm/immudb/helm/ | grep version | awk '{print $2}')

# !!! debian specific
if $(dpkg --compare-versions $VERSION_CURRENT "lt" $VERSION_LATEST);
then
    echo "we can update";

    helm upgrade \
        --install \
        --namespace codenotary \
        --set ingress.enabled=true \
        --set ingress.className=nginx \
        --set ingress.tls.enabled=true \
        --set image.tag=$VERSION_LATEST \
        --debug
        immudb ./immudb/helm/
else
    echo "we are at the latest"
fi
