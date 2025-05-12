resource "aws_efs_file_system" "efs-eks" {
  #checkov:skip=CKV_AWS_184:Temporary for test we will add kms key and rotation
  count            = local.aws_resources.enable_efs ? 1 : 0
  creation_token   = "efs-${local.cluster_name}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = "EfsEKS"
  }
}

resource "aws_efs_mount_target" "efs-eks" {
  #checkov:skip=CKV2_AWS_184:Temporary for test we will add kms key and rotation
  for_each        = { for sub_id in data.aws_subnets.private_subnets.ids : sub_id => sub_id if local.aws_resources.enable_efs }
  file_system_id  = aws_efs_file_system.efs-eks[0].id
  subnet_id       = each.value
  security_groups = [local.cluster_info.node_security_group_id, local.cluster_info.cluster_security_group_id]
}
