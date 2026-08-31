terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "github" {
  owner = split("/", var.github_repository)[0]
  token = var.github_token
}
