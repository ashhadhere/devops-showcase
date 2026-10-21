output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "controller_role_arn" { value = aws_iam_role.controller.arn }
output "node_security_group_id" { value = aws_security_group.nodes.id }
output "control_plane_security_group_id" { value = aws_security_group.control_plane.id }
output "addon_versions" { value = merge({ "vpc-cni" = aws_eks_addon.cni.addon_version }, { for k, a in aws_eks_addon.after_nodes : k => a.addon_version }) }
