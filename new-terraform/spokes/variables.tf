variable "kms_key_admin_roles" {
  description = "list of role ARNs to add to the KMS policy"
  type        = list(string)
  default     = []

}

variable "hub_account_id" {
  description = "We are using this to allow permissions on the hub account to read the secret and KMS key for cross account hub and spoke"
  default     = ""
}

variable "route53_zone_name" {
  description = "the Name of Route53 zone for external dns"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "The prefix name of the vpc for the data to loof for it"
  type        = string
}

variable "accounts_config" {
  description = "Map of objects for per environment configuration"
  type = map(object({
    account_id = string
  }))
}

################################################################################
# Cluster Realted Variables
################################################################################
variable "external_secrets_cross_account_role" {
  description = "The role that is on app tooling and hib to allow spoke clusters to get secret infromations from the accounts"
  default     = ""
}

variable "tenant" {
  description = "Name of the tenant where the cluster belongs to"
  type        = string
}

variable "cluster_type" {
  description = "The type of cluster if it belong to tenant or to platorfom team"
  type        = string
}

variable "hub_cluster_name" {
  description = "Enabling Automode Cluster"
  type        = string
  default     = "hub-cluster"
}

variable "deployment_environment" {
  description = "The environment that this cluster will be deployd this can be np,prelife,prod"
  default     = ""
  type        = string
}

variable "kubernetes_version" {
  type        = string
  description = "The version of the Kubernetes cluster"
}

variable "aws_resources" {
  description = "Enabling or desabling pod identity via terraform"
  type        = any
  default     = {}
}

variable "enable_automode" {
  description = "Enabling Automode Cluster"
  type        = bool
  default     = false
}

variable "use_ack" {
  description = "Defining to use ack or terraform for pod identity if this is true then we will use this label to deploy resouces with ack"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name that will be used for argo ingress"
  type        = string
  default     = ""
}

variable "remote_spoke_secret" {
  description = "If this is true then the secret is deploed on the Hub account if this is false its allowing"
  type        = bool
  default     = false
}

variable "amp_prometheus_crossaccount_role" {
  description = "Adot Role in the App tooling account that will allow to connect with prometheus"
  type        = string
  default     = ""
}

variable "environment_prefix" {
  description = "Prefix for different workspace envrironments"
  default     = ""
  type        = string
}