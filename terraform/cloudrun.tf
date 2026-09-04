resource "google_service_account" "web" {
  account_id   = "cutedraw-web"
  display_name = "Cutedraw frontend (Cloud Run)"

  depends_on = [google_project_service.required]
}

resource "google_cloud_run_v2_service" "web" {
  name     = var.web_service_name
  location = var.region

  deletion_protection = false
  # The load balancer is the only public ingress path. This prevents the run.app URL from bypassing
  # the canonical host, HTTPS policy, and Cloud CDN.
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  depends_on = [google_project_service.required]

  template {
    service_account = google_service_account.web.email
    timeout         = "3600s"

    scaling {
      min_instance_count = var.min_instances
      # Collaboration rooms are held in memory. Keep all WebSocket clients on
      # the same instance until a shared Socket.IO adapter is introduced.
      max_instance_count = 1
    }

    containers {
      image = var.app_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    # Terraform owns service configuration; the release workflow advances the immutable image.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# The application is public, but the ingress restriction above ensures traffic still enters through
# the Google load balancer rather than the default Cloud Run hostname.
resource "google_cloud_run_v2_service_iam_member" "web_public" {
  name     = google_cloud_run_v2_service.web.name
  location = google_cloud_run_v2_service.web.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
