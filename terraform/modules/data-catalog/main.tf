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

### Business Metadata Tag Template

resource "google_data_catalog_tag_template" "tag_template_business_metadata" {
  tag_template_id = var.business_metadata_template_name
  project = var.project
  region = var.region
  display_name = var.business_metadata_template_display_name

  fields {
    field_id = "data_owner"
    display_name = "Data Owner"
    order = 1
    type {
      primitive_type = "STRING"
    }
    is_required = false
  }

  fields {
    field_id = "data_product"
    display_name = "Data Product"
    order = 2
    type {
      primitive_type = "STRING"
    }
    is_required = false
  }

  fields {
    field_id = "data_level"
    display_name = "Data Level"
    order = 3
    type {
      enum_type {
        dynamic allowed_values {
          for_each = var.data_levels

          content {
            display_name = allowed_values.value
          }
        }
      }
    }
    is_required = false
  }

  fields {
    field_id = "data_product_type"
    display_name = "Data Product Type"
    order = 3
    type {
      enum_type {
        dynamic allowed_values {
          for_each = var.data_product_types

          content {
            display_name = allowed_values.value
          }
        }
      }
    }
    is_required = false
  }

  fields {
    field_id = "is_final_product"
    display_name = "Is Final Product"
    order = 2
    type {
      primitive_type = "BOOL"
    }
    is_required = false
  }

  // deleting the tag template will delete all configs attached to tables
  force_delete = true
}

resource "google_data_catalog_tag_template_iam_member" "tag_template_user" {
  count = length(var.business_metadata_tag_template_users)
  tag_template = google_data_catalog_tag_template.tag_template_business_metadata.name
  role = "roles/datacatalog.tagTemplateUser"
  member = "serviceAccount:${var.business_metadata_tag_template_users[count.index]}"
}