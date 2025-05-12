
################################################################################
# AWS Secret Manager to read the secret for github repo application
################################################################################
data "aws_secretsmanager_secret" "git_data_addons" {
  name = var.git_creds_secret
}

data "aws_secretsmanager_secret_version" "git_data_version_addons" {
  secret_id = data.aws_secretsmanager_secret.git_data_addons.id
}

# Decode the JSON string into a map
locals {
  git_data = jsondecode(data.aws_secretsmanager_secret_version.git_data_version_addons.secret_string)
}

################################################################################
# GitOps Bridge: Private ssh keys for git
################################################################################
resource "kubernetes_namespace" "argocd" {
  depends_on = [local.cluster_info]

  metadata {
    name = local.argocd_namespace
  }
}
resource "kubernetes_secret" "git_secrets" {
  depends_on = [kubernetes_namespace.argocd]
  for_each = {
    git-addons = {
      type                    = "git"
      url                     = local.gitops_addons_repo_url
      githubAppID             = base64decode(local.git_data["github_app_id"])
      githubAppInstallationID = base64decode(local.git_data["github_app_installation_id"])
      githubAppPrivateKey     = base64decode(local.git_data["github_private_key"])
    }
    git-fleet = {
      type                    = "git"
      url                     = local.gitops_fleet_repo_url
      githubAppID             = base64decode(local.git_data["github_app_id"])
      githubAppInstallationID = base64decode(local.git_data["github_app_installation_id"])
      githubAppPrivateKey     = base64decode(local.git_data["github_private_key"])
    }
    git-resources = {
      type                    = "git"
      url                     = local.gitops_resources_repo_url
      githubAppID             = base64decode(local.git_data["github_app_id"])
      githubAppInstallationID = base64decode(local.git_data["github_app_installation_id"])
      githubAppPrivateKey     = base64decode(local.git_data["github_private_key"])
    }
    argocd-bitnami = {
      type      = "helm"
      url       = "charts.bitnami.com/bitnami"
      name      = "Bitnami"
      enableOCI = true
    }
    ecr-token-secret-0 = {
      type      = "helm"
      url       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
      name      = "ecr-charts"
      enableOCI = true
      username  = "AWS"
      password  = data.aws_ecr_authorization_token.token.password
    }
  }
  metadata {
    name      = each.key
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = each.value
}

# Creating parameter for argocd hub role for the spoke clusters to read
resource "aws_ssm_parameter" "argocd_hub_role" {
  name  = "/${local.cluster_name}/argocd-hub-role"
  type  = "String"
  value = module.argocd_hub_pod_identity.iam_role_arn
}
################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source  = "gitops-bridge-dev/gitops-bridge/helm"
  version = "0.1.0"
  cluster = {
    cluster_name = try(module.eks[0].cluster_name, module.eks_auto[0].cluster_name)
    environment  = local.environment
    metadata     = local.addons_metadata
    addons       = local.addons
  }

  apps = local.argocd_apps
  argocd = {
    name             = "argocd"
    namespace        = local.argocd_namespace
    chart_version    = "7.7.8"
    values           = [file("${path.module}/argocd-initial-values.yaml")]
    timeout          = 600
    create_namespace = false
  }
  depends_on = [kubernetes_secret.git_secrets]
}

################################################################################
# Secret Required to Register spoke to HUB Deployed on the Hub account
################################################################################

resource "aws_secretsmanager_secret" "hub_secret" {
  name = "${local.cluster_name}/${local.cluster_name}"
  # kms_key_id              = aws_kms_key.spoke_secret_kmsp[0].id
  recovery_window_in_days = 0
}

# Example of Having the Secret on the Spoke Account and Allow Access from HUB external Secrets to pull it
resource "aws_secretsmanager_secret_version" "hub_secret" {
  secret_id = aws_secretsmanager_secret.hub_secret.id
  secret_string = jsonencode({
    cluster_name = local.cluster_info.cluster_name
    metadata     = local.addons_metadata
    addons       = local.addons
    config = {
      tlsClientConfig = {
        insecure = false,
        caData   = local.cluster_info.cluster_certificate_authority_data
      },
    }
  })
}