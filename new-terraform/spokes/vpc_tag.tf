################################################################################
# Tagging Subents for Loadbalancer configuration and CNI discovery
################################################################################
resource "aws_ec2_tag" "private_subnets" {
  for_each    = toset(data.aws_subnets.private_subnets.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnets_lb" {
  for_each    = toset(data.aws_subnets.private_subnets.ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.cluster_name}"
  value       = "owned"
}

resource "aws_ec2_tag" "intra_subnets_worker" {
  for_each    = toset(data.aws_subnets.intra_subnets.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/cni"
  value       = "1"
}

resource "aws_ec2_tag" "intra_subnets_worker_karpenter" {
  for_each    = toset(data.aws_subnets.intra_subnets.ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
