variable "project_id" {
  description = "Google Cloud project ID hosting Cutedraw. Project creation and billing attachment are bootstrap steps outside this stack."
  type        = string
  default     = "cutedraw"
}

variable "region" {
  description = "Region for Cloud Run, its serverless NEG, and Artifact Registry."
  type        = string
  default     = "northamerica-northeast1"
}

variable "site_domain" {
  description = "Apex hostname serving Cutedraw."
  type        = string
  default     = "cutedraw.app"
}

variable "www_domain" {
  description = "Secondary hostname serving the same application."
  type        = string
  default     = "www.cutedraw.app"
}

variable "web_service_name" {
  description = "Cloud Run service serving the built Cutedraw application."
  type        = string
  default     = "cutedraw-web"
}

variable "app_image" {
  description = <<-EOT
    Image used only to create the first Cloud Run revision. The deploy workflow owns subsequent
    immutable image digests, so Terraform ignores changes to the deployed image.
  EOT
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "min_instances" {
  description = "Minimum warm Cloud Run instances. Zero avoids idle compute cost."
  type        = number
  default     = 0
}

variable "cert_version" {
  description = "Suffix for the Google-managed certificate. Increment to force clean reissuance after a failed DNS validation."
  type        = number
  default     = 1
}

variable "certificate_manager_active" {
  description = <<-EOT
    Whether the HTTPS proxy serves the DNS-authorized Certificate Manager certificate map.
    Leave false until cutedraw-dns-cert reports ACTIVE, then change the default to true and apply.
  EOT
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "Exact owner/name of the GitHub repository allowed to deploy through Workload Identity Federation."
  type        = string
  default     = "powerm1nt/cutedraw"
}
