# Fetch Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Fetch supported OKE node pool images
data "oci_containerengine_node_pool_option" "oke" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

# VCN
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${var.prefix}-vcn"
  dns_label      = "${var.prefix}vcn"
}

# Internet Gateway
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-ig"
}

# Route Table
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Security List for Worker Nodes & API Server
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-security-list"

  # Outbound traffic to anywhere
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Inbound SSH access
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Inbound Kubernetes API access (Port 6443)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Internal communication within VCN
  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }
}

# Subnet 1: For Worker Nodes & Cluster API Endpoint
resource "oci_core_subnet" "nodes" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${var.prefix}-nodes-subnet"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
  dns_label         = "${var.prefix}nodes"
}

# Subnet 2: Dedicated strictly for OKE Load Balancers
resource "oci_core_subnet" "lb" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.2.0/24"
  display_name      = "${var.prefix}-lb-subnet"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
  dns_label         = "${var.prefix}lb"
}

# Managed OKE Basic Cluster (Control Plane is $0 / Free)
resource "oci_containerengine_cluster" "k8s_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = "v1.36.1" # Adjust to your desired supported K8s version
  name               = "${var.prefix}-oke-cluster"
  vcn_id             = oci_core_vcn.main.id
  type               = "BASIC_CLUSTER" # Basic cluster is free

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.nodes.id
  }

  options {
    # Uses dedicated Load Balancer subnet
    service_lb_subnet_ids = [oci_core_subnet.lb.id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

# Managed Worker Node Pool
resource "oci_containerengine_node_pool" "k8s_node_pool" {
  cluster_id         = oci_containerengine_cluster.k8s_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = oci_containerengine_cluster.k8s_cluster.kubernetes_version
  name               = "${var.prefix}-node-pool"
  node_shape         = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  node_source_details {
    image_id    = element([for img in data.oci_containerengine_node_pool_option.oke.sources : img.image_id if length(regexall("aarch64", img.source_name)) > 0], 0)
    source_type = "IMAGE"
    boot_volume_size_in_gbs = 50
  }

  node_config_details {
    size = 2
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.nodes.id
    }
  }

  ssh_public_key = file(var.ssh_public_key_path)
}

# Command helper to easily fetch your local kubeconfig
output "kubeconfig_command" {
  value = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.k8s_cluster.id} --file ~/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}
