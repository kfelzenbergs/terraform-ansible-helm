variable "host_interface" {
    type            =   string
    description     =   "Network adapter name on host machine for bridged network interface setup"
    default         =   "wlp0s20f3"
}

variable "node_name" {
    type            =   string
    description     =   "Network adapter name on host machine for bridged network interface setup"
    default         =   "node-k8s"
}
