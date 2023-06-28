#
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

provider "google" {
  alias  = "impersonation"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonation
  target_service_account = var.terraform_service_account
  scopes                 = [
    "userinfo-email",
    "cloud-platform"
  ]
  lifetime = "1200s"
}

provider "google" {
  project = var.project
  region  = var.compute_region

  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}

provider "google-beta" {
  project = var.project
  region  = var.compute_region

  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}

locals {
  common_labels = {
    "environment" : var.environment,
    "application" : var.application_name,
    "provisioned_by" : "terraform",
  }

  apis        = [
    "cloudresourcemanager",
    "iam",
    "datacatalog",
    "artifactregistry",
    "bigquery",
    "storage",
    "cloudbuild",
    "serviceusage",
    "compute",
    "cloudfunctions",
    "run",
    "bigqueryconnection"
  ]
}

// enable all required APIs
resource "google_project_service" "project_api" {
  count   = length(local.apis)
  project = var.project
  service = "${local.apis[count.index]}.googleapis.com"

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}

# create a bucket to stage cloud functions deployment
resource "google_storage_bucket" "resources_bucket" {
  name                        = "${var.project}-cf-resources"
  location                    = var.data_region
  force_destroy               = true
  uniform_bucket_level_access = true
  depends_on                  = [google_project_service.project_api]
}


data "google_project" "project" {
  depends_on                  = [google_project_service.project_api]
}

module "bigquery" {
  source = "./modules/bigquery"
  common_labels = local.common_labels
  project = var.project
  region = var.data_region
  resources_dataset_name = var.resources_dataset_name
}

module "data-catalog" {
  source = "./modules/data-catalog"
  project = var.project
  region = var.data_region
  business_metadata_tag_template_users = [
    module.tag_table_function.cloud_function_sa_email
  ]

  data_levels            = var.data_levels
  data_product_types     = var.data_product_types

  depends_on             = [google_project_service.project_api]
}

# BQ Remote Function for entgeltatlas
module "entgelt_atlas_function" {
  source = "./modules/bq-remote-function"
  function_name = "entgelt_atlas" # only underscores allowed
  cloud_function_src_dir  = "../cloud-functions/entgeltatlas"
  cloud_function_temp_dir = "/tmp/entgelt-atlas.zip"
  service_account_name = "sa-func-entgelt-atlas"
  function_entry_point = "process_request"
  env_variables = {}
  project = var.project
  region = var.compute_region
  resource_bucket_name = google_storage_bucket.resources_bucket.name
  bigquery_dataset_name = module.bigquery.resources_dataset_id
  deployment_procedure_path = "modules/bq-remote-function/procedures/deploy_entgelt_atlas_remote_func.tpl"
  cloud_functions_sa_extra_roles = []

  depends_on             = [google_project_service.project_api]
}

# BQ Remote Function for tagging tables
module "tag_table_function" {
  source = "./modules/bq-remote-function"
  function_name = "tag_bq_table" # only underscores allowed
  cloud_function_src_dir  = "../cloud-functions/tag-bq-table"
  cloud_function_temp_dir = "/tmp/tag-bq-table.zip"
  service_account_name = "sa-func-tag-bq-table"
  function_entry_point = "process_request"
  env_variables = {
    TAG_TEMPLATE_PROJECT : var.project
    TAG_TEMPLATE_REGION : var.data_region
    TAG_TEMPLATE_ID : module.data-catalog.business_metadata_tag_template_id
  }
  project = var.project
  region = var.compute_region
  resource_bucket_name = google_storage_bucket.resources_bucket.name
  bigquery_dataset_name = module.bigquery.resources_dataset_id
  deployment_procedure_path = "modules/bq-remote-function/procedures/deploy_tag_bq_table_remote_func.tpl"
  cloud_functions_sa_extra_roles = [
    "roles/datacatalog.tagEditor",
    "roles/datacatalog.tagTemplateUser",
    "roles/datacatalog.viewer"
  ]

  depends_on             = [google_project_service.project_api]
}




