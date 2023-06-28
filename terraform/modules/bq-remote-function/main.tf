# /*
# * Copyright 2023 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *     https://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */

##### BigQuery Connection

resource "google_bigquery_connection" "connection" {
  connection_id = var.function_name
  project       = var.project
  location      = var.region

  ## Note: The cloud resource nested object has only one output only field - serviceAccountId.
  cloud_resource {}
}

##### Entgelt atlas Cloud Function #################################

resource "google_service_account" "sa_function" {
  project      = var.project
  account_id   = var.service_account_name
  display_name = "Runtime SA for Cloud Function ${var.function_name}"
}

# Permissions needed for the cloud function SA
resource "google_project_iam_member" "sa_function_roles" {
  project  = var.project
  for_each = toset(concat([
    "roles/logging.logWriter",
    "roles/artifactregistry.reader"
  ],
    var.cloud_functions_sa_extra_roles
  ))
  role   = each.key
  member = "serviceAccount:${google_service_account.sa_function.email}"
}

#####################################################

# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
  type        = "zip"
  source_dir  = var.cloud_function_src_dir
  output_path = var.cloud_function_temp_dir
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files' content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = var.resource_bucket_name
}

resource "google_cloudfunctions2_function" "function" {
  name     = var.function_name
  project  = var.project
  location = var.region

  build_config {
    runtime     = "python310"
    entry_point = var.function_entry_point  # Set the entry point
    source {
      storage_source {
        bucket = var.resource_bucket_name
        object = google_storage_bucket_object.zip.name
      }
    }
  }

  service_config {
    max_instance_count               = 3
    min_instance_count               = 1
    available_memory                 = "1Gi"
    timeout_seconds                  = 60
    max_instance_request_concurrency = 80
    available_cpu                    = "2"
    environment_variables            = var.env_variables
    ingress_settings                 = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision   = true
    service_account_email            = google_service_account.sa_function.email
  }
}

resource "google_cloud_run_service_iam_member" "sa_invoker" {
  project  = var.project
  location = var.region
  service  = google_cloudfunctions2_function.function.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_bigquery_connection.connection.cloud_resource[0].service_account_id}"

  depends_on = [google_bigquery_connection.connection, google_cloudfunctions2_function.function]
}

#########

# create a stored procedure that deploys the function and call it from outside Terraform

resource "google_bigquery_routine" "routine_deploy_functions" {
  dataset_id      = var.bigquery_dataset_name
  routine_id      = "deploy_${var.function_name}"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = templatefile(var.deployment_procedure_path,
    {
      project            = var.project
      dataset            = var.bigquery_dataset_name
      function_name      = "remote_${var.function_name}"
      region             = var.region
      connection_name    = google_bigquery_connection.connection.connection_id
      cloud_function_url = google_cloudfunctions2_function.function.service_config[0].uri
    }
  )
}


## generate a random string suffix for the bq job
resource "random_string" "random" {
  length  = 20
  special = false
}

## Run a BQ job to deploy the remote functions
resource "google_bigquery_job" "deploy_remote_functions_job" {
  job_id   = "d_job_${google_bigquery_routine.routine_deploy_functions.routine_id}_${random_string.random.result}"
  location = var.region

  query {
    priority = "INTERACTIVE"
    query    = "CALL ${var.bigquery_dataset_name}.${google_bigquery_routine.routine_deploy_functions.routine_id}();"
    create_disposition = "" # must be set to "" for scripts
    write_disposition = ""  # must be set to "" for scripts
  }
}