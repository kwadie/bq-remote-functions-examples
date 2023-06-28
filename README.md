# BigQuery Remote Functions Examples (end-to-end)

## Overview

This repo contains end-to-end examples and reusable Terraform modules to author and deploy 
[BigQuery remote functions](https://cloud.google.com/bigquery/docs/remote-functions#:~:text=A%20BigQuery%20remote%20function%20allows,in%20BigQuery%20user%2Ddefined%20functions.)

BigQuery remote functions extends BigQuery's SQL capabilities by using Cloud Functions to encapsulate application logic
(programmed in a variety of languages) and calling these functions from the SQL realm.

The Terraform modules in the project automate the steps required to deploy such a Cloud Function, the BigQuery 
remote function connection and wrapper around it and required IAM resources and bindings.

### Example 1: Attaching Cloud Data Catalog metadata tag templates to BigQuery tables

In a Data Mesh environment, we should be able to search for data products within the organization using different
parameters. One way of achieving this is to define metadata attributes and templates by the data governance team 
and re-use them across data teams/products. A minimal example of such metadata attributes could be:
* Data Owner: email of the person/team owning this asset
* Data Product: which data product this asset belong to
* Data Product Type: types could be source-aligned data products, analytics products, governance products, etc
* Data Level: which zone in the data platform/lake the asset belongs to (e.g. Raw data, Refined data, etc)
* Is Final Product: a boolean flag determining if this asset ready for consumption as a product or is it an intermediate one

In GCP this is done by defining [Data Catalog metadata templates](https://cloud.google.com/data-catalog/docs/tags-and-tag-templates)
and attaching them to tables. After that, these metadata attributes could be used to search for data products (e.g. BigQuery
tables, datasets, PubSub topics, etc).

The repo defines and deploy a sample Tag Template and Remote Function that attach that tag to a given table. The remote
function is called from SQL and thus makes it part of SQL-based workflows (e.g. Dataform, dbt, etc) without the need
for a workflow orchestration tool (i.e. Airflow, Composer, Cloud Workflows, etc).

After deploying the code, one could tag a table using this SQL snippet:

```roomsql
SELECT resources.remote_tag_bq_table(
  "<project_id>.resources.sample_table_customer", -- table spec
  "customer360team@company.com", -- data owner
  "Customer360", -- data product
  "RAW", -- data level
  "Source Data Product", -- data product type
  true -- is final product
  );
```

### Example 2: Query public API data

Before BigQuery remote functions, we had to extract data from external private or public APIs (using non-sql applications)
, ingest it to BigQuery and only then we are able to query it or join it with other BigQuery data.  

With remote functions, we could encapsulate the API data extraction logic (e.g. authentication, requests, etc)
in a Cloud Function and call it from SQL with the required parameters. This could be used for SQL-based data
ingestion (direct API-to-BigQuery), data enrichment in ETL pipelines or just simply for providing a SQL interface
for users and Data Analysts to query API data from their SQL console.

This repo defines and deploy a remote function that extract German wage statistics from the publicly available API 
[Entgelt Atlas](https://github.com/bundesAPI/entgeltatlas-api). If you're using Chrome, you can translate the page
from German to English if needed.

The function expects the following parameters: Occupation Class, Performance Level, Regions, Gender, Age and Occupation
Branch. Please check the [API docs](https://github.com/bundesAPI/entgeltatlas-api) for reference values of these parameters.

After deploying the code, one could query the API data using this SQL snippet:
```roomsql
WITH sample_data AS
(
  SELECT 'person_1' AS person_id, 84304 AS occuptaion_code, 2 AS gender
  UNION ALL
  SELECT 'person_2' AS person_id, 84304 AS occuptaion_code, 3 AS gender
)
,api_calls AS
(
--  remote_entgelt_atlas(occupation_class, performance_level, region, gender, age, branch)
SELECT
d.*,
resources.remote_entgelt_atlas(d.occuptaion_code ,4,1,d.gender,1,1) AS api_result_json
FROM sample_data d
)

SELECT
*,
JSON_VALUE(api_result_json, '$.kldb') AS occupation_classification,
JSON_VALUE(api_result_json, '$.region.bezeichnung') AS region,
JSON_VALUE(api_result_json, '$.gender.bezeichnung') AS gender,
JSON_VALUE(api_result_json, '$.ageCategory.bezeichnung') AS age_category,
JSON_VALUE(api_result_json, '$.performanceLevel.bezeichnung') AS performance_level,
JSON_VALUE(api_result_json, '$.branche.bezeichnung') AS branche,
JSON_VALUE(api_result_json, '$.entgelt') AS wage,
JSON_VALUE(api_result_json, '$.entgeltQ25') AS wage_q25,
JSON_VALUE(api_result_json, '$.entgeltQ75') AS wage_q75
FROM api_calls
```

## Terraform Deployment

#### Set Variables
```shell
export PROJECT_ID=
export COMPUTE_REGION=
export ACCOUNT=user@company.com
export BUCKET=${PROJECT_ID}-terraform
export TF_SA=terraform
```

Create (or activate) a gcloud account for that project
```shell
export CONFIG=remote-functions-ex
gcloud config configurations create $CONFIG

gcloud config set project $PROJECT_ID
gcloud config set account $ACCOUNT
gcloud config set compute/region $COMPUTE_REGION
```

Auth gcloud
```
gcloud auth login --project $PROJECT_ID
gcloud auth application-default login --project $PROJECT_ID
```

#### Enable GCP APIs

```shell
./scripts/enable_gcp_apis.sh
```


#### Prepare Terraform Service Account

Terraform needs to run with a service account to deploy DLP resources. User accounts are not enough.

```shell
./scripts/prepare_terraform_service_account.sh
```

#### Prepare Terraform State Bucket

```shell
./scripts/prepare_terraform_bucket.sh
```

#### Terraform Variables Configuration

The solution is deployed by Terraform and thus all configurations are done
on the Terraform side.

##### Create a Terraform .tfvars file

Create a new .tfvars file and override the variables in the below sections. You can use the example
tfavrs files as a base [example-variables.tfvars](terraform/example-variables.tfvars).

```shell
export VARS=variables.tfvars
```

##### Configure Project Variables

Most required variables have default values defined in [variables.tf](terraform/variables.tf).
One can use the defaults or overwrite them in the newly created .tfvars.

Both ways, one must set the below variables:

```yaml
environment = "<environment level POC|DEV|STG|PRD>"
project = "<GCP project ID to deploy solution to (equals to $PROJECT_ID) >"
compute_region = "<GCP region to deploy compute resources e.g. cloud run, iam, etc (equals to $COMPUTE_REGION)>"
data_region = "<GCP region to deploy data resources (buckets, datasets, tag templates, etc> (equals to $DATA_REGION)"
```

##### Configure Terraform Service Account

Terraform needs to run with a service account to deploy DLP resources. User accounts are not enough.

This service account name is defined in the "Setup Environment Variables" step and created
in the "Prepare Terraform Service Account" step.
Use the full email of the created account.
```yaml
terraform_service_account = "${TF_SA}@${PROJECT_ID}.iam.gserviceaccount.com"
```

#### Deploy Terraform

Terraform needs to run with a service account to deploy DLP resources. User accounts are not enough.

```shell
./scripts/deploy_terraform.sh
```


#### Post Terraform Deployment

Some resources are not deployable from Terraform. These have to be deployed at a later step:

##### Deploying BigQuery Remote Functions
Terraform deploys BigQuery stored procedures that encapsulates the
creation scripts for remote functions. It also executes these stored procedure and
report the job status as part of Terraform output. Note the jobs status and make sure they are "SUCCESSFUL" 




