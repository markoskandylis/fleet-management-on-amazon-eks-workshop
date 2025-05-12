# ################################################################################
# # Using Enabling Shared Cloudwatch Account for Monitoring
# ################################################################################
# data "aws_oam_sinks" "example" {
#   provider = aws.shared-services
# }


# resource "aws_oam_link" "eks_insights" {
#   label_template = "$AccountName"
#   link_configuration {
#     metric_configuration {
#       filter = "Namespace IN ('AWS/EKS', 'ContainerInsights', 'Kubernetes')"
#     }
#     log_group_configuration {
#       filter = "LogGroupName LIKE '/aws/eks/%' OR LogGroupName LIKE '/aws/containerinsights/%' OR LogGroupName LIKE '/aws/eks-fargate/%'"
#     }
#   }
#   resource_types  = ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup"]
#   sink_identifier = tolist(data.aws_oam_sinks.example.arns)[0]
# }

################################################################################
# ADOT
################################################################################

data "aws_ssm_parameter" "amp_arn" {
  provider = aws.shared-services
  count    = local.aws_resources.enable_prometheus_scraper ? 1 : 0
  name     = "/${var.environment_prefix}/amp-arn"
}

data "aws_ssm_parameter" "amp_endpoint" {
  provider = aws.shared-services
  count    = local.aws_resources.enable_prometheus_scraper ? 1 : 0
  name     = "/${var.environment_prefix}/amp-endpoint"
}


module "adot_collector_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.4.0"

  name = "amp-prometheus-server-sa"

  policy_statements = [
    {
      sid       = "ampCrossaccount"
      actions   = ["sts:AssumeRole", "sts:TagSession"]
      resources = [var.amp_prometheus_crossaccount_role]
    }
  ]

  # Pod Identity Associations
  associations = {
    addon = {
      cluster_name    = local.cluster_info.cluster_name
      namespace       = local.addons_metadata.amp_prometheus_namespace
      service_account = local.addons_metadata.amp_prometheus_serviceaccount
    }
  }
  tags = local.tags
}
