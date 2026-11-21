data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

data "oci_containerengine_node_pool_option" "oke" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

locals {
  # Image must match the cluster version. Names embed the build date, so the last sorted match is newest.
  oke_version_tag = "OKE-${trimprefix(var.kubernetes_version, "v")}-"
  node_images = {
    for s in data.oci_containerengine_node_pool_option.oke.sources : s.source_name => s.image_id
    if startswith(s.source_name, "Oracle-Linux-9") &&
    strcontains(s.source_name, "aarch64") &&
    !strcontains(s.source_name, "GPU") &&
    strcontains(s.source_name, local.oke_version_tag)
  }
  node_image_name = element(sort(keys(local.node_images)), length(local.node_images) - 1)
  node_image_id   = local.node_images[local.node_image_name]

  vcn_cidr = "10.0.0.0/16"
}

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [local.vcn_cidr]
  display_name   = "${var.prefix}-vcn"
  dns_label      = "${var.prefix}vcn"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-ig"
}

# No NAT gateway on free tier, so nodes sit in a public subnet.
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

resource "oci_core_security_list" "nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-nodes-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "all"
    source   = local.vcn_cidr
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.admin_cidrs
    content {
      description = "kubectl from admin"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 6443
        max = 6443
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.admin_cidrs
    content {
      description = "SSH from admin"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }
}

# LoadBalancer Services must set security-list-management-mode "None", or OKE's
# cloud controller edits these lists and the next apply reverts it.
resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.prefix}-lb-sl"

  egress_security_rules {
    destination = local.vcn_cidr
    protocol    = "6"
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  dynamic "ingress_security_rules" {
    for_each = [80, 443]
    content {
      protocol = "6"
      source   = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }
}

resource "oci_core_subnet" "nodes" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${var.prefix}-nodes-subnet"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.nodes.id]
  dns_label         = "${var.prefix}nodes"
}

resource "oci_core_subnet" "lb" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.2.0/24"
  display_name      = "${var.prefix}-lb-subnet"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.lb.id]
  dns_label         = "${var.prefix}lb"
}

# BASIC is free; ENHANCED is billed hourly.
resource "oci_containerengine_cluster" "k8s_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.prefix}-oke-cluster"
  vcn_id             = oci_core_vcn.main.id
  type               = "BASIC_CLUSTER"

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.nodes.id
  }

  options {
    service_lb_subnet_ids = [oci_core_subnet.lb.id]
  }
}

resource "oci_containerengine_node_pool" "k8s_node_pool" {
  cluster_id         = oci_containerengine_cluster.k8s_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = oci_containerengine_cluster.k8s_cluster.kubernetes_version
  name               = "${var.prefix}-node-pool"
  node_shape         = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_gbs
  }

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
      subnet_id           = oci_core_subnet.nodes.id
    }

    node_pool_pod_network_option_details {
      cni_type = "FLANNEL_OVERLAY"
    }
  }

  # Boot volumes over 50 GB aren't usable until the root FS is grown. Custom
  # user_data replaces OKE's default, so it must run the OKE init script itself.
  node_metadata = var.node_boot_volume_gbs > 50 ? {
    user_data = filebase64("${path.module}/scripts/node-init.sh")
  } : {}

  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
}

output "node_image" {
  value = local.node_image_name
}

output "cluster_id" {
  value = oci_containerengine_cluster.k8s_cluster.id
}
