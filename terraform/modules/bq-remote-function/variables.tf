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

variable "service_account_name" {
  type = string
}

variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "function_name" {
  type = string
}

variable "cloud_function_src_dir" {
  type = string
}

variable "cloud_function_temp_dir" {
  type = string
}

variable "resource_bucket_name" {
  type = string
}

variable "function_entry_point" {
  type = string
}

variable "env_variables" {
  type = map(string)
}

variable "bigquery_dataset_name" {
  type = string
}

variable "deployment_procedure_path" {
  type = string
}

variable "cloud_functions_sa_extra_roles" { type = list(string) }