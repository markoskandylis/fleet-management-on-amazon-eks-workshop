
################################################################################
# External Secrets EKS Pod Identity for Extenal Secrets
# In this example we use external secrets For both Fleet namespace and Notmal External secret namespace
################################################################################
module "external_secrets_pod_identity" {
  count   = local.aws_resources.enable_external_secrets_pod_identity ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name = "external-secrets"
  # Example of policy Statement to allow Extrnal Secret Operator of Spoke account to pull Secrets from HUB
  policy_statements = [
    {
      sid       = "crossaccount"
      actions   = ["sts:AssumeRole", "sts:TagSession"]
      resources = [var.external_secrets_cross_account_role]
    }
  ]

  # Give Permitions to External secret to Assume Remote From Hub Account
  external_secrets_kms_key_arns         = ["arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:*"]
  external_secrets_ssm_parameter_arns   = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  attach_external_secrets_policy        = true
  external_secrets_create_permission    = false

  # Pod Identity Associations
  associations = {
    addon = {
      cluster_name    = local.cluster_info.cluster_name
      namespace       = "argocd"
      service_account = local.external_secrets.service_account
    }
  }

  tags = local.tags
}

module "external_secrets_pod_identity_local" {
  count   = local.aws_resources.enable_external_secrets_pod_identity_local ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name = "external-secrets"

  # Give Permitions to External secret to Assume Remote From Hub Account
  external_secrets_kms_key_arns         = ["arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:*"]
  external_secrets_ssm_parameter_arns   = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  attach_external_secrets_policy        = true
  external_secrets_create_permission    = false

  # Pod Identity Associations
  associations = {
    addon = {
      cluster_name    = local.cluster_info.cluster_name
      namespace       = "argocd"
      service_account = local.external_secrets.service_account
    }
  }

  tags = local.tags
}

################################################################################
# EBS CSI EKS Access
################################################################################
module "aws_ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name = "aws-ebs-csi"

  attach_aws_ebs_csi_policy = true
  aws_ebs_csi_kms_arns      = ["arn:aws:kms:*:*:key/*"]

  # Pod Identity Associations
  associations = {
    addon = {
      cluster_name    = local.cluster_info.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = local.tags
}
################################################################################
# AWS ALB Ingress Controller EKS Access
################################################################################
module "aws_lb_controller_pod_identity" {
  count   = local.enable_automode || local.aws_resources.enable_aws_lb_controller_pod_identity ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name = "aws-lbc"

  attach_aws_lb_controller_policy = true


  # Pod Identity Associations
  associations = {
    addon = {
      cluster_name    = local.cluster_info.cluster_name
      namespace       = local.aws_load_balancer_controller.namespace
      service_account = local.aws_load_balancer_controller.service_account
    }
  }

  tags = local.tags
}

module "ack_iam_eks_identity" {
  #checkov:skip=CKV_TF_1:commit hash not required
  #checkov:skip=CKV_TF_2:seems to be a bug in checkov
  count   = local.use_ack ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name            = "${local.cluster_name}-ack-pod-identity"
  use_name_prefix = false

  attach_custom_policy     = true
  policy_statements        = data.aws_iam_policy_document.iam_management_policy[0].statement
  permissions_boundary_arn = aws_iam_policy.permissions_boundary_eks_ack[0].arn
  # Pod Identity Associations
  association_defaults = {
    namespace = "ack-system"
  }
  associations = {
    iam_controller = {
      cluster_name    = local.cluster_info.cluster_name
      service_account = local.iam_ack.service_account
    }
    eks_controller = {
      cluster_name    = local.cluster_info.cluster_name
      service_account = local.eks_ack.service_account
    }
  }

  tags = local.tags
}

data "aws_iam_policy_document" "iam_management_policy" {
  count = local.use_ack ? 1 : 0
  statement {
    sid    = "RoleManagement"
    effect = "Allow"
    actions = [
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PassRole",
      "iam:DetachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:CreateRole",
      "iam:UntagRole",
      "iam:TagRole",
      "iam:AttachRolePolicy",
      "iam:GetRolePolicy"
    ]
    resources = [
      # Policies with specific prefixes
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_info.cluster_name}*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
    }
  }

  statement {
    sid    = "PolicyManagement"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:GetPolicyVersion",
      "iam:GetPolicy"
    ]
    resources = [
      # Policies with specific prefixes
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_info.cluster_name}*",
    ]
  }

  statement {
    sid    = "IAMACKListOperations"
    effect = "Allow"
    actions = [
      "iam:ListRoles",
      "iam:ListPolicies",
      "iam:GetRole",
      "iam:ListRoleTags",
      "iam:ListRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListPolicyTags",
      "iam:ListAttachedRolePolicies",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_info.cluster_name}*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_info.cluster_name}*",
    ]
  }
  statement {
    sid    = "eksack"
    effect = "Allow"
    actions = [
      # EKS Pod Identity specific permissions
      "eks:CreatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
      "eks:UpdatePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
      "eks:DescribePodIdentityAssociation",
      "eks:TagResource",   # For tagging pod identity associations
      "eks:UntagResource", # For untagging pod identity associations

      # Required supporting permissions
      "iam:PassRole",       # Required to pass IAM roles to EKS
      "ec2:DescribeSubnets" # Required for network configuration
    ]
    resources = [
      local.cluster_info.cluster_arn,
      "arn:aws:eks:${local.region}:${data.aws_caller_identity.current.account_id}:podidentityassociation/${local.cluster_info.cluster_name}/*"
    ]
  }
}

# Permission boundaries to restrict access to ACM, SSM and EKS
data "aws_iam_policy_document" "permissions_boundary_eks_ack" {
  count = local.use_ack ? 1 : 0
  statement {
    sid       = "EKSACKSSMDescribe"
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  statement {
    sid    = "EKSACKSSMParameterAccess"
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  }

  statement {
    sid    = "EKSACKIAMAllowed"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_info.cluster_name}*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_info.cluster_name}*",
    ]
  }

  statement {
    sid    = "IAMACKListOperations"
    effect = "Allow"
    actions = [
      "iam:ListRoles",
      "iam:ListPolicies",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListPolicyTags",
      "iam:TagRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_info.cluster_name}*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_info.cluster_name}*",
    ]
  }

  statement {
    sid       = "EKSACKSecretsManagerList"
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }

  statement {
    sid    = "EKSACKSecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetSecretValue",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:DescribeSecret"
    ]
    resources = ["arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:*"]
  }

  statement {
    sid       = "EKSACKKMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  }

  statement {
    sid    = "EKSACKACMCertificateManagement"
    effect = "Allow"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:ExportCertificate",
      "acm:RequestCertificate",
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "acm:DeleteCertificate",
      "acm:RenewCertificate",
      "acm:UpdateCertificateOptions"
    ]
    resources = ["arn:aws:acm:${local.region}:${data.aws_caller_identity.current.account_id}:certificate/*"]
  }

  statement {
    sid    = "EKSACKACMPCAAccess"
    effect = "Allow"
    actions = [
      "acm-pca:DescribeCertificateAuthority",
      "acm-pca:GetCertificate",
      "acm-pca:GetCertificateAuthorityCertificate"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "EKSACKIssueACMPCAAccess"
    effect = "Allow"
    actions = [
      "acm-pca:IssueCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EKSACKEKSPodIdentityManagement"
    effect = "Allow"
    actions = [
      "eks:CreatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
      "eks:UpdatePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
      "eks:DescribePodIdentityAssociation",
      "eks:TagResource",
      "eks:UntagResource",
      "iam:PassRole",
      "ec2:DescribeSubnets"
    ]
    resources = [
      local.cluster_info.cluster_arn,
      "arn:aws:eks:${local.region}:${data.aws_caller_identity.current.account_id}:podidentityassociation/${local.cluster_info.cluster_name}/*"
    ]
  }

  statement {
    sid    = "EKSACKDenyPermBoundaryIAMPolicyAlteration"
    effect = "Deny"
    actions = [
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
  }

  statement {
    sid    = "EKSACKDenyRemovalOfPermBoundaryFromAnyRole"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
    }
  }

  statement {
    sid       = "EKSACKNoBoundaryUserDelete"
    effect    = "Deny"
    actions   = ["iam:DeleteUserPermissionsBoundary"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/*"]
  }

  statement {
    sid    = "EKSACKDenyAccessIfRequiredPermBoundaryIsNotBeingApplied"
    effect = "Deny"
    actions = [
      "iam:PutRolePermissionsBoundary"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
    }
  }

  statement {
    sid    = "EKSACKDenyUserAndRoleCreationWithoutPermBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
    }
  }

  # deny role modifications without boundary
  statement {
    sid    = "EKSACKDenyRoleModificationWithoutBoundary"
    effect = "Deny"
    actions = [
      "iam:UpdateRole",
      "iam:PutRolePolicy",
      "iam:AttachRolePolicy",
      "iam:UpdateAssumeRolePolicy"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ack-bountries"]
    }
  }

}

resource "aws_iam_policy" "permissions_boundary_eks_ack" {
  count       = local.use_ack ? 1 : 0
  name        = "${local.cluster_name}-ack-bountries"
  path        = "/"
  description = "Permissions boundary policy for IAM users and roles"
  policy      = data.aws_iam_policy_document.permissions_boundary_eks_ack[0].json
}