variable "region" { 
  type    = string 
  default = "us-ashburn-1"
}

variable "compartment_ocid" { 
  type = string 
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
