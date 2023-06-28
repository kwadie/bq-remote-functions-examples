CREATE OR REPLACE FUNCTION `${project}.${dataset}`.${function_name}(
table_spec STRING,
table_data_owner STRING,
table_data_product STRING,
table_data_level STRING,
table_data_product_type STRING,
table_is_final_product BOOL
) RETURNS JSON

REMOTE WITH CONNECTION `${project}.${region}.${connection_name}`
OPTIONS (
  endpoint = "${cloud_function_url}"
);