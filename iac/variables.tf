variable "region" {
  type    = string
  default = "us-ashburn-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment to create everything in (currently the tenancy root)"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "prefix" {
  type        = string
  description = "Prefix prepended to resource names"
  default     = "neptune"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the Kubernetes API (6443) and node SSH (22). Use your public IP as x.x.x.x/32."
}

variable "kubernetes_version" {
  type        = string
  description = "OKE version for control plane and nodes. List options: oci ce cluster-options get --cluster-option-id all"
  default     = "v1.37.1"
}

variable "availability_domain_index" {
  type        = number
  description = "Which AD (0-2) to place nodes in. Change this if you hit 'Out of host capacity' for A1."
  default     = 0
}

# --- Always Free budget (this tenancy's hard limits) ---------------------------
#   A1 compute:     2 OCPU / 12 GB RAM total   (node_count * ocpus / memory)
#   Block storage:  200 GB total, boot volumes included. OCI PVCs are min 50 GB.
#   Load balancer:  1 flexible LB @ 10 Mbps
# Defaults: one node using all A1 compute. 150 GB left for PVCs.

variable "node_count" {
  type    = number
  default = 1
}

variable "node_ocpus" {
  type    = number
  default = 2
}

variable "node_memory_gbs" {
  type    = number
  default = 12
}

variable "node_boot_volume_gbs" {
  type        = number
  description = "Minimum is 50. Anything above 50 also needs the filesystem grown on first boot (see node_metadata in main.tf)."
  default     = 50
}

variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID (quotas are tenancy-level)"
}
