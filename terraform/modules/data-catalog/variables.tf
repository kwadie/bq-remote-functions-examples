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

variable "project" { type = string }
variable "region" { type = string }
variable "business_metadata_template_name" {
  type    = string
  default = "table_metadata_template"
}
variable "business_metadata_template_display_name" {
  type = string
  default = "Business Metadata Template"
}

variable "data_levels" {
  type = list(string)
}

variable "data_product_types" {
  type = list(string)
}

variable "business_metadata_tag_template_users" {
  type = list(string)
}