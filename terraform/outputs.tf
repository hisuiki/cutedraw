output "load_balancer_ip" {
  description = "Global address published in Cloudflare DNS."
  value       = google_compute_global_address.web.address
}

output "site_urls" {
  description = "Public Cutedraw URLs covered by the Google-managed certificate."
  value = [
    "https://${var.site_domain}",
    "https://${var.www_domain}",
  ]
}

output "cloud_run_service" {
  description = "Cloud Run service advanced by the deployment workflow."
  value       = google_cloud_run_v2_service.web.name
}

output "url_map" {
  description = "URL map passed to the CDN invalidation command after deployment."
  value       = google_compute_url_map.web.name
}

output "artifact_registry_repository" {
  description = "Docker repository used by the deployment workflow."
  value       = "${google_artifact_registry_repository.containers.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

output "workload_identity_provider" {
  description = "Set as the GCP_WORKLOAD_IDENTITY_PROVIDER GitHub repository secret."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "Set as the GCP_DEPLOY_SERVICE_ACCOUNT GitHub repository secret."
  value       = google_service_account.deployer.email
}

output "certificate_dns_authorization_record" {
  description = "CNAME record published through Cloudflare MCP to authorize the replacement certificate."
  value = {
    name = google_certificate_manager_dns_authorization.web.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.web.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.web.dns_resource_record[0].data
  }
}
