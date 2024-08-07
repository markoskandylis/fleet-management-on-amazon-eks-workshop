#!/usr/bin/env bash

set -euo pipefail

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOTDIR="$(cd ${SCRIPTDIR}/../..; pwd )"
[[ -n "${DEBUG:-}" ]] && set -x

# Delete the Ingress/SVC before removing the addons
TMPFILE=$(mktemp)
terraform -chdir=$SCRIPTDIR output -raw configure_kubectl > "$TMPFILE"
# check if TMPFILE contains the string "No outputs found"
if [[ ! $(cat $TMPFILE) == *"No outputs found"* ]]; then
  echo "No outputs found, skipping kubectl delete"
  source "$TMPFILE"
  kubectl delete svc -n argocd argo-cd-argocd-server
fi


terraform -chdir=$SCRIPTDIR destroy -target="module.gitops_bridge_bootstrap" -auto-approve
terraform -chdir=$SCRIPTDIR destroy -target="module.eks_blueprints_addons" -auto-approve
terraform -chdir=$SCRIPTDIR destroy -target="module.eks" -auto-approve

echo "remove VPC endpoints"
VPCID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=fleet-hub-cluster" --query "Vpcs[*].VpcId" --output text)
echo $VPCID
for endpoint in $(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPCID" --query "VpcEndpoints[*].VpcEndpointId" --output text); do
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $endpoint
done

terraform -chdir=$SCRIPTDIR destroy -target="module.vpc" -auto-approve
terraform -chdir=$SCRIPTDIR destroy -auto-approve
