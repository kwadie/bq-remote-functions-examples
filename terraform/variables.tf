variable "environment" {
  type = string
  description = "Environment level (e.g. poc, dev, stg, prd)"
}

variable "application_name" {
  type = string
  default = "bq_remote_functions_examples"
  description = "Application name"
}

variable "project" {
  type = string
  description = "GCP project id to deploy resources to"
}

variable "compute_region" {
  type = string
  description = "GCP region to deploy compute resources to"
}

variable "data_region" {
  type = string
  description = "GCP region to deploy data resources to"
}

variable "resources_dataset_name" {
  type = string
  description = "BigQuery dataset name to store remote functions and resources"
  default = "resources"
}


variable "terraform_service_account" {
  type = string
  description = "Service account email used to deploy resources to GCP via Terraform"
}

variable "data_levels" {
  type = list(string)
  default = ["RAW", "REFINED", "CURATED"]
  description = "Dataplatform zones to be used in metadata catalog"
}

variable "data_product_types" {
  type = list(string)
  default = ["Source Data Product", "Analytics Data Product", "BI Data Product"]
  description = "Data product types to be used in metadata catalog"
}

