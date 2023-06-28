output "bq_tag_table_remote_function_deployment_status" {
  value = module.tag_table_function.deploy_job_status
}

output "bq_entgelt_atlas_remote_function_deployment_status" {
  value = module.entgelt_atlas_function.deploy_job_status
}