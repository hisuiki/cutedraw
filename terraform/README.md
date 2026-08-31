# Cutedraw infrastructure

This stack hosts Cutedraw on Google Cloud and uses Cloudflare only as the authoritative DNS provider for `cutedraw.app`.

| Resource | Purpose |
| --- | --- |
| Cloud Run `cutedraw-web` | Serves the built Vite application from nginx |
| Global external Application Load Balancer | Canonical HTTP/HTTPS ingress for the apex and `www` |
| Cloud CDN | Caches hashed application assets using nginx origin headers |
| Google-managed certificate | Covers `cutedraw.app` and `www.cutedraw.app` |
| Artifact Registry + Workload Identity Federation | Keyless deployments from `powerm1nt/cutedraw` |
| Cloudflare MCP | DNS-only apex A and `www` CNAME records pointing to GCP |

Cloudflare MCP inspection on 2026-08-31 confirmed that zone `a4a2f907b86ec4fe5b282bf2a2d5e9a3` is active in NukaWorks Solutions and initially contained no DNS records. Terraform manages only Google Cloud resources. The connected Cloudflare MCP owns the apex and `www` records so a separate API token is not stored locally or in CI. Cloudflare proxying, CDN, certificates, Workers, and analytics remain disabled.

## Bootstrap

The Google project, billing link, and state bucket are bootstrap resources: they must exist before Terraform can initialize its provider or backend.

```bash
gcloud projects create cutedraw --name=Cutedraw
gcloud billing projects link cutedraw --billing-account=YOUR_BILLING_ACCOUNT_ID

gcloud storage buckets create gs://cutedraw-tfstate-prod \
  --project=cutedraw \
  --location=US \
  --uniform-bucket-level-access
gcloud storage buckets update gs://cutedraw-tfstate-prod --versioning
```

If `cutedraw` or the state bucket name is already taken globally, choose available names and update `var.project_id` and `backend.tf` respectively before initializing.

```bash
gcloud auth application-default login

terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

State lives in the versioned GCS bucket and can contain infrastructure identifiers, so it must not be committed or made public.

## DNS through Cloudflare MCP

After Terraform creates the global address, use the connected Cloudflare MCP to create or update these records in zone `a4a2f907b86ec4fe5b282bf2a2d5e9a3`:

| Name | Type | Content | TTL | Proxied |
| --- | --- | --- | --- | --- |
| `cutedraw.app` | A | `terraform -chdir=terraform output -raw load_balancer_ip` | 300 | No |
| `www.cutedraw.app` | CNAME | `cutedraw.app` | 300 | No |

The static global address is Terraform-managed, so the MCP records only need changing if that address is deliberately replaced. Cloudflare MCP also owns the DNS authorization CNAME returned by `terraform -chdir=terraform output -json certificate_dns_authorization_record`; that record must remain DNS-only for automatic certificate renewal.

## First deployment

After the first apply, configure the GitHub repository from Terraform outputs:

| GitHub setting | Terraform value |
| --- | --- |
| Secret `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform -chdir=terraform output -raw workload_identity_provider` |
| Secret `GCP_DEPLOY_SERVICE_ACCOUNT` | `terraform -chdir=terraform output -raw deployer_service_account` |
| Variable `GCP_PROJECT_ID` | `cutedraw` (or your override) |
| Variable `GCP_REGION` | `northamerica-northeast1` |
| Variable `GCP_WEB_SERVICE` | `terraform -chdir=terraform output -raw cloud_run_service` |
| Variable `GCP_URL_MAP` | `terraform -chdir=terraform output -raw url_map` |

Push to the `cutedraw` branch or run the deployment workflow manually. The workflow builds one `linux/amd64` image, pushes it to Artifact Registry, resolves it to an immutable digest, deploys that digest to Cloud Run, and invalidates Cloud CDN.

For a local deployment with the same implementation:

```bash
gcloud auth login
scripts/build-and-deploy-gcp.sh --dry-run
scripts/build-and-deploy-gcp.sh
```

The HTTPS proxy uses a two-phase certificate migration. Keep `certificate_manager_active = false` while `cutedraw-dns-cert` is provisioning. After its DNS authorization CNAME is published through Cloudflare MCP and `gcloud certificate-manager certificates describe cutedraw-dns-cert` reports `ACTIVE`, change the default to `true` and apply. This prevents an unissued certificate map from interrupting HTTPS.
