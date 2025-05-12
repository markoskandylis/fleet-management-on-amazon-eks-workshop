locals {
  cluster_info           = try(module.eks[0], module.eks_auto[0])
  use_ack                = var.use_ack
  hub_cluster_name       = var.hub_cluster_name
  enable_automode        = var.enable_automode
  account_config         = var.accounts_config[terraform.workspace]
  cluster_name           = "spoke-${terraform.workspace}"
  fleet_member           = "spoke"
  environment            = terraform.workspace
  tenant                 = var.tenant
  region                 = data.aws_region.current.id
  cluster_version        = var.kubernetes_version
  argocd_namespace       = "argocd"
  domain_name            = var.domain_name
  deployment_environment = var.deployment_environment

  iam_ack = {
    namespace       = "ack-system"
    service_account = "iam-ack"
  }

  external_secrets = {
    namespace       = "platform-system"
    service_account = "external-secrets-sa"
  }

  aws_efs_csi_driver = {
    namespace                  = "kube-system"
    controller_service_account = "efs-csi-controller-sa"
    node_service_account       = "efs-csi-node-sa"
  }

  aws_load_balancer_controller = {
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller-sa"
  }

  eks_ack = {
    namespace       = "ack-system"
    service_account = "eks-ack"
  }

  amp_prometheus = {
    namespace       = "platform-system"
    service_account = "amp-prometheus-server-sa"
  }

  aws_resources = {
    enable_external_secrets_pod_identity       = try(var.aws_resources.enable_external_secrets_pod_identity, false)
    enable_external_secrets_pod_identity_local = try(var.aws_resources.enable_external_secrets_pod_identity_local, false)
    enable_aws_lb_controller_pod_identity      = try(var.aws_resources.enable_aws_lb_controller_pod_identity, false)
    enable_aws_efs_csi_driver_pod_identity     = try(var.aws_resources.enable_aws_efs_csi_driver_pod_identity, false)
    enable_eck_stack                           = try(var.aws_resources.enable_eck_stack, false)
    enable_efs                                 = try(var.aws_resources.enable_efs, false)
    enable_karpenter                           = try(var.aws_resources.enable_karpenter, false)
    enable_prometheus_scraper                  = try(var.aws_resources.enable_prometheus_scraper, false)
  }

  addons = merge(
    { fleet_member = local.fleet_member },
    { kubernetes_version = local.cluster_version },
    { domain_name = local.domain_name },
    { aws_cluster_name = local.cluster_info.cluster_name },
    { environment = local.deployment_environment }
  )

  addons_metadata = merge(
    {
      aws_cluster_name = local.cluster_info.cluster_name
      aws_region       = local.region
      aws_account_id   = data.aws_caller_identity.current.account_id
      aws_vpc_id       = data.aws_vpc.vpc.id
    },
    {
      aws_efs_csi_driver_controller_service_account = try(local.aws_efs_csi_driver.controller_service_account, "")
      aws_efs_csi_driver_node_service_account       = try(local.aws_efs_csi_driver.node_service_account, "")
      aws_efs_csi_driver_namespace                  = try(local.aws_efs_csi_driver.namespace, "")
      storageclass_file_system_id                   = try(aws_efs_file_system.efs-eks[0].id, "")
    },
    {
      ack_iam_service_account = local.iam_ack.service_account
      ack_iam_namespace       = local.iam_ack.namespace
      ack_eks_service_account = local.eks_ack.service_account
      ack_eks_namespace       = local.eks_ack.namespace
    },
    {
      external_secrets_namespace          = try(local.external_secrets.namespace, "")
      external_secrets_service_account    = try(local.external_secrets.service_account, "")
      external_secrets_cross_account_role = try(var.external_secrets_cross_account_role, "")
    },
    {
      # Opensource monitoring
      amp_endpoint_url                 = try(data.aws_ssm_parameter.amp_endpoint[0].value, "")
      amp_arn                          = try(data.aws_ssm_parameter.amp_arn[0].value, "")
      amp_prometheus_namespace         = try(local.amp_prometheus.namespace, "")
      amp_prometheus_serviceaccount    = try(local.amp_prometheus.service_account, "")
      amp_prometheus_crossaccount_role = try(var.amp_prometheus_crossaccount_role, "")
    }
  )

  cluster_admin_role_arns = [aws_iam_role.spoke.arn, tolist(data.aws_iam_roles.eks_admin_role.arns)[0]]
  # # Generate dynamic access entries for each admin rolelocals {
  admin_access_entries = {
    for role_arn in local.cluster_admin_role_arns : role_arn => {
      principal_arn = role_arn
      policy_associations = {
        admins = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Merging dynamic entries with static entries if needed
  access_entries = merge({}, local.admin_access_entries)

  tags = {
    Blueprint  = local.cluster_name
    GithubRepo = "github.com/gitops-bridge-dev/gitops-bridge"
  }
}
