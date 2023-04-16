# Infrastructure, Kubernetes cluster and application provisioning using IaC principles

The goal is to develop simple deployment using __Kubernetes/Helm__ that contains __immudb__ with read replica, an ingress that exposes immudb endpoints, and a __Grafana__ dashboard to see metrics. 

## Requirements
 - [X] Permanent storage for immudb and it’s replica
 - [X] Automated provisioning with one command, like “setup_cluster”
 - [X] Grafana dashboard with meaningful metrics
 - [X] Ingress using TLS
 - [ ] (optional) Ingress can load balance read request to immudb replica
 - [X] (optional) Health checks 
 - [X] (optional) Use KVM/Terraform (or other virtualization/automation technology) to install kubernetes cluster and run deployment in VM. 
 - [X] (optional) Automation of updates, i.e. when new version of immudb is released

 ### Implementation of requirements
  - Permanent storage for immudb and it's replica was provided via local-storage based persistent volume. New [storage-class.yaml](helm/immudb/helm/templates/storage-class.yaml) and [pv.yaml](helm/immudb/helm/templates/pv.yaml) manifests were introduced within immudb's helm chart. To make run the second instance of immudb as a replica the following set of environment variables were introduced in [values.yaml](helm/immudb/helm/values.yaml) and referenced in [statefulset.yaml](helm/immudb/helm/templates/statefulset.yaml).
  ```
  replicationIsReplica: false
  replicationPrimaryHost: ""
  replicationPrimaryUsername: ""
  replicationPrimaryPassword: ""
  replicationPrimaryPort: 3322
  ```
  - A bash script  [setup.sh](setup.sh) was developed to automate the whole setup.
  - [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) services were deployed using their helm chars. Persistent storage was provided with local-storage based persistent volume. A datasource of type Prometheus was configured in Grafana via service endpoint of Prometheus and dashboard loaded from [go-metrics_rev1.json](tooling/go-metrics_rev1.json).
  - For the ingress controller [ingress-nginx](https://kubernetes.github.io/ingress-nginx ) was used and deployed via helm. TLS was setup by using traefic annotations for the ingress (already set within the helm chart). TLS certificate was generated using the openssl command below and added to the newly introduced [certificate manifest](helm/immudb/helm/templates/certificate.yaml) within the helm.
  ```
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=immudb-example.localhost"
  ```
  - Load balancing on ingress level could be achieved by adding the other backend from the replica to the ingress resource definition. In that case the ingress will perform a [round-robin](https://www.nginx.com/resources/glossary/round-robin-load-balancing/#:~:text=What%20Is%20Round%2DRobin%20Load,to%20each%20server%20in%20turn.) based load balancing.
  - Healh checks are set within the already provided [immudb helm chart](https://github.com/codenotary/immudb/blob/master/helm/templates/statefulset.yaml#L51) by Codenotary and includes readiness and liveness probes for kubernetes
  - Infrastructure provisioned with Terraform using Virtualbox as a provider. As a base we take debian 11. Kubernetes cluster is further being setup using [Ansible](https://github.com/ansible/ansible). Kubernetes v1.27 with containerd runtime and [Flannel](https://github.com/flannel-io/flannel) for the network is used.
  - Updates of immudb are managed via [checkForUpdate.sh](checkForUpdate.sh) bash script which essentially checks the version from a local helm chart of immudb and compares it to the chart in the helm repo. If the version from the repository is higher it will do the update by adjusting `TAG` variable for immudb helm and will perform `helm upgrade`.

 ## Issues on the way
  - Typo / discrepancy for `storage.class` definition in the original helm chart within `satefulset.yaml` compared to `values.yaml`. Note the capital C for the `volume.Class` at [https://github.com/codenotary/immudb/blob/v1.4.1/helm/templates/statefulset.yaml#L96](https://github.com/codenotary/immudb/blob/v1.4.1/helm/templates/statefulset.yaml#L96)
  - Replication does not fully work and fails with the error below. Full logs can be viewed in [replication-error.log](logs/replication-error.log) 
  ```
  immudb 2023/04/15 07:48:42 ERROR: Error starting replication for database 'systemdb'. Reason: illegal arguments
  ```
 

## Resources
 - immudb: https://github.com/codenotary/immudb 
 - immudb docs: https://docs.immudb.io/master/ 
 - immudb metrics: https://docs.immudb.io/1.0.0/operations/monitoring.html
 - go metrics: https://grafana.com/grafana/dashboards/10826-go-metrics/
 - tf virtualbox provider: https://registry.terraform.io/providers/shekeriev/virtualbox/latest/docs
 - flannel: https://github.com/flannel-io/flannel
 - ansible: https://github.com/ansible/ansible
 - k8s health probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
 - ingress nginx: https://kubernetes.github.io/ingress-nginx 
 - prometheus: https://github.com/prometheus-community/helm-charts
