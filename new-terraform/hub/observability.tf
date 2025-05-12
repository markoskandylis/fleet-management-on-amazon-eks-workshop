# resource "aws_oam_sink" "this" {
#   name = "EKS-Observability"

#   tags = {
#     Env = "EKS-Observability"
#   }
# }

# resource "aws_oam_sink_policy" "this" {
#   sink_identifier = aws_oam_sink.this.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action   = ["oam:CreateLink", "oam:UpdateLink"]
#         Effect   = "Allow"
#         Resource = "*"
#         Principal = {
#           "AWS" = ["767398095856","008971676728"]

#         }
#         Condition = {
#           "ForAllValues:StringEquals" = {
#             "oam:ResourceTypes" = ["AWS::CloudWatch::Metric", "AWS::Logs::LogGroup", "AWS::XRay::Trace"]
#           }
#         }
#       }
#     ]
#   })
# }



# resource "aws_cloudwatch_dashboard" "cni-helper-cw-dashboard" {
#   dashboard_name = "Fleet_Management_Vpc_Cni"
#   dashboard_body = replace(
#     replace(file("cw-dashboard-vpc-cni.json"), "**aws_region**", local.region),
#     "**default_cluster**", local.name
#   )
# }

# resource "aws_cloudwatch_dashboard" "karpenter-cw-dashboard" {
#   dashboard_name = "Fleet_Management_Karpenter"
#   dashboard_body = replace(
#     replace(file("cw-dashboard-karpenter.json"), "**aws_region**", local.region),
#     "**default_cluster**", local.name
#   )
# }

# resource "aws_cloudwatch_dashboard" "coredns-cw-dashboard" {
#   dashboard_name = "Fleet_Management_CoreDNS"
#   dashboard_body = replace(
#     replace(file("cw-dashboard-coredns.json"), "**aws_region**", local.region),
#     "**default_cluster**", local.name
#   )
# }
