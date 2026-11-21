# Cost guardrails for a Pay As You Go tenancy.
#
# Always Free tenancies have hard service limits; upgrading to PAYG (needed for
# OKE) lifts them so overages get billed. These quotas re-impose the Always Free
# ceilings so OCI refuses anything that would cost money. Apply these BEFORE
# upgrading the account.

resource "oci_limits_quota" "free_tier" {
  compartment_id = var.tenancy_ocid
  name           = "${var.prefix}-free-tier-caps"
  description    = "Cap usage at OCI Always Free allowances"

  statements = [
    # Compute: only A1 Flex, 2 OCPU / 12 GB (= 1,500 OCPU-h / 9,000 GB-h per month)
    "zero compute-core quotas in tenancy",
    "zero compute-memory quotas in tenancy",
    "set compute-core quota standard-a1-core-count to 2 in tenancy",
    "set compute-memory quota standard-a1-memory-count to 12 in tenancy",
    # Regional counters are separate from the per-AD ones; both must be set.
    "set compute-core quota standard-a1-core-regional-count to 2 in tenancy",
    "set compute-memory quota standard-a1-memory-regional-count to 12 in tenancy",

    # Block storage (boot volumes + PVCs share this)
    "set block-storage quota total-storage-gb to 200 in tenancy",
    # oracle.com/cloud/free lists 2 free block volumes (docs list only 200 GB + 5 backups)
    "set block-storage quota volume-count to 2 in tenancy",
    "set block-storage quota backup-count to 5 in tenancy",

    # One 10 Mbps flexible load balancer
    "zero load-balancer quotas in tenancy",
    "set load-balancer quota lb-flexible-count to 1 in tenancy",
    "set load-balancer quota lb-flexible-bandwidth-sum to 10 in tenancy",

    # OKE: one BASIC cluster, no paid enhanced clusters or virtual nodes.
    # (Nodes per cluster is not quota-able; nodes are capped by the A1 quota above.)
    "zero container-engine quotas in tenancy",
    "set container-engine quota cluster-count to 1 in tenancy",
  ]
}

# Spend alerting: an existing $1/month budget ("primary-spend-budget", created
# in the console) emails on any actual spend; it is not managed here.
