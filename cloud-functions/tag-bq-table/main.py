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

import functions_framework
from flask import jsonify
from google.cloud import logging
import os
from google.cloud import datacatalog_v1


@functions_framework.http
def process_request(request):
    try:

        tag_template_project = os.environ.get('TAG_TEMPLATE_PROJECT')
        tag_template_region = os.environ.get('TAG_TEMPLATE_REGION')
        tag_template_id = os.environ.get('TAG_TEMPLATE_ID')

        logger = logging.Client().logger("tag_table_log")

        request_json = request.get_json()

        # the function should be implemented in a way that recieves a batch of calls. Each element in the calls array is 1 record-level invocation in BQ SQL
        calls = request_json['calls']

        calls_count = len(calls)
        logger.log_text(
            f"Received {calls_count} calls from BQ. Calls: " + str(calls),
            severity="INFO"
        )

        datacatalog_client = datacatalog_v1.DataCatalogClient()

        replies = []
        for call in calls:
            logger.log_text(
                f"Will process bq call " + str(call),
                severity="INFO"
            )
            table_spec = call[0].strip('`')
            table_owner = call[1]
            table_data_product = call[2]
            table_zone = call[3]
            data_product_type = call[4]
            is_final_product = call[5]

            # Lookup Data Catalog's Entry referring to the table.
            table_spec_splits = table_spec.split(".")
            table_project = table_spec_splits[0]
            table_dataset = table_spec_splits[1]
            table_name = table_spec_splits[2]
            resource_name = (
                f"//bigquery.googleapis.com/projects/{table_project}"
                f"/datasets/{table_dataset}/tables/{table_name}"
            )
            table_entry = datacatalog_client.lookup_entry(
                request={"linked_resource": resource_name}
            )

            # Attach a Tag to the table.
            tag = datacatalog_v1.Tag()
            tag.template = f'projects/{tag_template_project}/locations/{tag_template_region}/tagTemplates/{tag_template_id}'

            data_owner_field = datacatalog_v1.TagField()
            data_owner_field.string_value = table_owner
            tag.fields['data_owner'] = data_owner_field

            data_product_field = datacatalog_v1.TagField()
            data_product_field.string_value = table_data_product
            tag.fields['data_product'] = data_product_field

            data_level_field = datacatalog_v1.TagField()
            data_level_field.enum_value.display_name = table_zone
            tag.fields['data_level'] = data_level_field

            data_product_type_field = datacatalog_v1.TagField()
            data_product_type_field.enum_value.display_name = data_product_type
            tag.fields['data_product_type'] = data_product_type_field

            is_final_field = datacatalog_v1.TagField()
            is_final_field.bool_value = is_final_product
            tag.fields['is_final_product'] = is_final_field

            # check if the table already has this tag attached with previous values
            get_tags_request = datacatalog_v1.ListTagsRequest(parent=table_entry.name)
            get_tags_page_result = datacatalog_client.list_tags(request=get_tags_request)
            existing_tag_name = None
            for response in get_tags_page_result:
                if response.template.endswith(tag_template_id):
                    existing_tag_name = response.name
                    break

            data_catalog_method = "create" if existing_tag_name is None else "update"
            if data_catalog_method == "create":
                datacatalog_client.create_tag(parent=table_entry.name, tag=tag)
            else:
                tag.name = existing_tag_name
                datacatalog_client.update_tag(tag=tag)

            call_result = {"table_spec": table_spec, "status": "SUCCESS", "data_catalog_method": data_catalog_method}
            replies.append(call_result)

        return_json = jsonify({"replies": replies})
        logger.log_text(
            f"Function call ending. Replies {replies}",
            severity="INFO"
        )
        return return_json

    except Exception as e:
        return jsonify({"errorMessage": str(e)}), 400
