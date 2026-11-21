variable "region" {
  type    = string
  default = "us-east-1"
}
variable "certificate_arn" {
  type        = string
  description = "Prevalidated regional ACM certificate; HTTPS is mandatory."
}
variable "operator_cidrs" {
  type        = set(string)
  description = "Explicit approved client CIDRs for HTTPS ingress. No public default."
  validation {
    condition     = length(var.operator_cidrs) > 0 && !contains(var.operator_cidrs, "0.0.0.0/0")
    error_message = "Use explicit approved CIDRs."
  }
}
variable "image_digests" {
  type        = map(string)
  description = "Full ECR image URIs pinned by @sha256 for four services, collector and bootstrap."
  validation {
    condition     = alltrue([for image in values(var.image_digests) : can(regex("^[0-9]+[.]dkr[.]ecr[.].+[.]amazonaws[.]com/.+@sha256:[0-9a-f]{64}$", image))]) && alltrue([for s in ["account-service", "ledger-service", "transfer-service", "projection-worker", "collector", "bootstrap"] : contains(keys(var.image_digests), s)])
    error_message = "Supply all six ECR image digests."
  }
}
variable "desired_count" {
  type        = number
  default     = 0
  description = "Keep zero through DB bootstrap. Set one only during authorized deployment."
  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 2
    error_message = "Sandbox supports zero to two replicas."
  }
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "deletion_protection" {
  type    = bool
  default = true
}

