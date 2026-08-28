terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
  backend "oci" {
    bucket               = "neptune-terraform-state-bucket"
    namespace            = "idgweocdyx8k"
    key                  = "neptune/terraform.tfstate"
    region               = "us-ashburn-1"
    config_file_profile  = "DEFAULT"
  }
}

provider "oci" {
  config_file_profile = "DEFAULT"
  region              = var.region
}
