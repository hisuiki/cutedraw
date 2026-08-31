# A global external Application Load Balancer is the canonical public entry point. Cloud CDN follows
# the cache headers emitted by nginx: hashed assets are immutable and the SPA shell is never cached.

resource "google_compute_global_address" "web" {
  name       = "cutedraw-lb-ip"
  depends_on = [google_project_service.required]
}

resource "google_compute_region_network_endpoint_group" "web" {
  name                  = "cutedraw-web-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.web.name
  }
}

resource "google_compute_backend_service" "web" {
  name                  = "cutedraw-web-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = true

  cdn_policy {
    cache_mode        = "USE_ORIGIN_HEADERS"
    negative_caching  = false
    serve_while_stale = 60

    cache_key_policy {
      include_host         = true
      include_protocol     = true
      include_query_string = true
    }
  }

  backend {
    group = google_compute_region_network_endpoint_group.web.id
  }
}

resource "google_compute_url_map" "web" {
  name            = "cutedraw-url-map"
  default_service = google_compute_backend_service.web.id
}

# Compute managed certificates validate through public DNS. The Cloudflare records in dns.tf are
# DNS-only so they expose the load balancer IP directly during issuance and renewal.
resource "google_compute_managed_ssl_certificate" "web" {
  name = "cutedraw-cert-v${var.cert_version}"

  managed {
    domains = [var.site_domain, var.www_domain]
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_project_service.required]
}

resource "google_compute_target_https_proxy" "web" {
  name    = "cutedraw-https-proxy"
  url_map = google_compute_url_map.web.id

  # Keep the classic certificate attached until the DNS-authorized Certificate Manager
  # replacement is ACTIVE. Attaching an unissued certificate map would close TLS connections.
  ssl_certificates = var.certificate_manager_active ? [] : [google_compute_managed_ssl_certificate.web.id]
  certificate_map = var.certificate_manager_active ? (
    "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.web.id}"
  ) : null
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "cutedraw-https"
  target                = google_compute_target_https_proxy.web.id
  port_range            = "443"
  ip_address            = google_compute_global_address.web.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Plain HTTP is retained only to redirect to the same host over HTTPS.
resource "google_compute_url_map" "http_redirect" {
  name = "cutedraw-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }

  depends_on = [google_project_service.required]
}

resource "google_compute_target_http_proxy" "http_redirect" {
  name    = "cutedraw-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "cutedraw-http"
  target                = google_compute_target_http_proxy.http_redirect.id
  port_range            = "80"
  ip_address            = google_compute_global_address.web.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
