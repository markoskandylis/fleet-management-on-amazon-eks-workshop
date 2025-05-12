resource "aws_efs_file_system" "efs-eks" {
  count            = local.enable_efs ? 1 : 0
  creation_token   = "efs-${local.cluster_name}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = "EfsEKS"
  }
}

resource "aws_efs_mount_target" "efs-eks" {
  for_each        = { for sub_id in data.aws_subnets.private_subnets.ids : sub_id => sub_id if local.enable_efs }
  file_system_id  = aws_efs_file_system.efs-eks[0].id
  subnet_id       = each.value
  security_groups = [module.eks[0].node_security_group_id, module.eks[0].cluster_security_group_id]
}
