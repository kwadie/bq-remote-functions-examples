CREATE OR REPLACE FUNCTION `${project}.${dataset}`.${function_name}(
occupation_class INT64,
performance_level INT64,
region INT64,
gender INT64,
age INT64,
branch INT64
) RETURNS JSON

REMOTE WITH CONNECTION `${project}.${region}.${connection_name}`
OPTIONS (
  endpoint = "${cloud_function_url}"
);