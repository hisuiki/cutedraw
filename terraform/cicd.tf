# GitHub Actions exchanges its repository-scoped OIDC token for short-lived Google credentials.
# No service-account key is created or stored as a repository secret.

resource "google_artifact_registry_repository" "containers" {
  repository_id = "containers"
  location      = var.region
  format        = "DOCKER"
  description   = "Production container images for Cutedraw."

  depends_on = [google_project_service.required]
}

resource "google_service_account" "deployer" {
  account_id   = "github-deployer"
  display_name = "Cutedraw GitHub Actions deployer"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # A token from any other GitHub repository is rejected before service-account impersonation.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_impersonation" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# gcloud and Docker credential helpers may mint an access token explicitly after
# the OIDC exchange. Keep this grant scoped to the repository principal.
resource "google_service_account_iam_member" "github_token_creator" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_artifact_registry_repository_iam_member" "deployer_push" {
  repository = google_artifact_registry_repository.containers.name
  location   = google_artifact_registry_repository.containers.location
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "deployer_run" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account_iam_member" "deployer_act_as_web" {
  service_account_id = google_service_account.web.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# No predefined role combines only the two permissions needed by gcloud's CDN invalidation command.
resource "google_project_iam_custom_role" "cdn_invalidator" {
  role_id     = "cdnCacheInvalidator"
  title       = "CDN cache invalidator"
  description = "Purge Cutedraw Cloud CDN content without changing load-balancer routing."
  permissions = [
    "compute.urlMaps.get",
    "compute.urlMaps.invalidateCache",
  ]

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "deployer_cdn_invalidate" {
  project = var.project_id
  role    = google_project_iam_custom_role.cdn_invalidator.id
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

locals {
  github_repository_name = element(split("/", var.github_repository), 1)
}

# Keep the repository's deployment configuration in sync with the resources above.
# The GitHub provider reads GITHUB_TOKEN when var.github_token is left unset.
resource "github_actions_secret" "workload_identity_provider" {
  repository  = local.github_repository_name
  secret_name = "GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = google_iam_workload_identity_pool_provider.github.name
}

resource "github_actions_secret" "deployer_service_account" {
  repository  = local.github_repository_name
  secret_name = "GCP_DEPLOY_SERVICE_ACCOUNT"
  value       = google_service_account.deployer.email
}

resource "github_actions_variable" "project_id" {
  repository    = local.github_repository_name
  variable_name = "GCP_PROJECT_ID"
  value         = var.project_id
}

resource "github_actions_variable" "region" {
  repository    = local.github_repository_name
  variable_name = "GCP_REGION"
  value         = var.region
}

resource "github_actions_variable" "web_service" {
  repository    = local.github_repository_name
  variable_name = "GCP_WEB_SERVICE"
  value         = google_cloud_run_v2_service.web.name
}

resource "github_actions_variable" "url_map" {
  repository    = local.github_repository_name
  variable_name = "GCP_URL_MAP"
  value         = google_compute_url_map.web.name
}

resource "github_actions_repository_permissions" "this" {
  repository           = local.github_repository_name
  enabled              = true
  allowed_actions      = "all"
  sha_pinning_required = false
}
