terraform {
  required_version = ">= 1.5"
  required_providers {
    # kind cluster é provisionado via `kind create cluster` (null_resource + local-exec)
    # porque o provider tehcyx/kind v0.11.0 crashava (ver docs/decisoes/).
    null = { source = "hashicorp/null", version = "~> 3.2" }
  }
  backend "local" {}
}
