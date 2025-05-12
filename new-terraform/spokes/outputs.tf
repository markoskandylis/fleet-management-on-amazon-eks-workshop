output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = <<-EOT
    export KUBECONFIG="/tmp/${local.cluster_info.cluster_name}"
    aws eks --region ${local.region} update-kubeconfig --name ${local.cluster_info.cluster_name}
  EOT
}

