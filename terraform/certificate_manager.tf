# The classic Compute managed certificate can fail visibility checks while a new domain is becoming
# visible. Certificate Manager proves control independently through a stable DNS authorization and
# can cover both the apex and the wildcard used by www.

resource "google_certificate_manager_dns_authorization" "web" {
  name        = "cutedraw-dns-auth"
  domain      = var.site_domain
  description = "Proves control of cutedraw.app for Google-managed certificate issuance."

  depends_on = [google_project_service.required]
}

resource "google_certificate_manager_certificate" "web" {
  name        = "cutedraw-dns-cert"
  description = "DNS-authorized certificate for the Cutedraw apex and subdomains."

  managed {
    domains = [var.site_domain, "*.${var.site_domain}"]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.web.id,
    ]
  }

  depends_on = [google_project_service.required]
}

resource "google_certificate_manager_certificate_map" "web" {
  name = "cutedraw-cert-map"

  depends_on = [google_project_service.required]
}

resource "google_certificate_manager_certificate_map_entry" "web" {
  name         = "cutedraw-primary"
  map          = google_certificate_manager_certificate_map.web.name
  matcher      = "PRIMARY"
  certificates = [google_certificate_manager_certificate.web.id]
}
