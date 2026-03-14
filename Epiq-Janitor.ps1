Write-Host "🚨 INITIATING EPIQ MASTER JANITOR SCRIPT 🚨" -ForegroundColor Red
Write-Host "Targeting all Epiq Ghost Resources across Azure and AWS..." -ForegroundColor Yellow

# ==========================================
# 1. AZURE CLEANUP (The Easy Way)
# ==========================================
Write-Host "`n[1/5] Nuking Azure Resource Group..." -ForegroundColor Cyan
az group delete --name Epiq-PROD-RG --yes --no-wait
Write-Host "✅ Azure WORM Vault and Sentinel queued for destruction." -ForegroundColor Green

# ==========================================
# 2. AWS APP LAYER CLEANUP (Breaking the Locks)
# ==========================================
Write-Host "`n[2/5] Assassinating AWS Load Balancers & Target Groups..." -ForegroundColor Cyan

# Find and delete ALBs
$albArns = aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'epiq')].LoadBalancerArn" --output text
if ($albArns) {
    foreach ($alb in $albArns -split '\s+') {
        Write-Host "   Deleting ALB: $alb"
        aws elbv2 delete-load-balancer --load-balancer-arn $alb
    }
    Write-Host "   Waiting 15 seconds for ALB deletion to propagate..."
    Start-Sleep -Seconds 15
}

# Find and delete Target Groups (Including the Ghost ones)
$tgArns = aws elbv2 describe-target-groups --query "TargetGroups[?contains(TargetGroupName, 'epiq')].TargetGroupArn" --output text
if ($tgArns) {
    foreach ($tg in $tgArns -split '\s+') {
        Write-Host "   Deleting Target Group: $tg"
        aws elbv2 delete-target-group --target-group-arn $tg 2>$null
    }
}

# ==========================================
# 3. AWS COMPUTE CLEANUP (ECS & ECR)
# ==========================================
Write-Host "`n[3/5] Terminating ECS Fargate Containers & ECR Vault..." -ForegroundColor Cyan

# Force delete ECS Service
Write-Host "   Scaling down and deleting ECS Service..."
aws ecs update-service --cluster epiq-discovery-cluster --service epiq-discovery-service --desired-count 0 2>$null
aws ecs delete-service --cluster epiq-discovery-cluster --service epiq-discovery-service --force 2>$null

# Delete ECS Cluster
Write-Host "   Destroying ECS Cluster..."
aws ecs delete-cluster --cluster epiq-discovery-cluster 2>$null

# Force empty and delete ECR Repository
Write-Host "   Nuking ECR Image Repository..."
aws ecr delete-repository --repository-name epiq-discovery-engine --force 2>$null

# ==========================================
# 4. AWS IAM & STATE CLEANUP (The Ghosts)
# ==========================================
Write-Host "`n[4/5] Exorcising IAM Roles and Ghost State..." -ForegroundColor Cyan

# Delete Execution Role
aws iam detach-role-policy --role-name epiq_ecs_execution_role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>$null
aws iam delete-role --role-name epiq_ecs_execution_role 2>$null

# Delete GitHub Role
aws iam detach-role-policy --role-name epiq-github-oidc-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>$null
aws iam delete-role --role-name epiq-github-oidc-role 2>$null

# ==========================================
# 5. TERRAFORM CACHE WIPE
# ==========================================
Write-Host "`n[5/5] Wiping Local Terraform Memory..." -ForegroundColor Cyan
if (Test-Path "terraform-aws/.terraform") { Remove-Item -Recurse -Force "terraform-aws/.terraform" }
if (Test-Path "terraform-aws/.terraform.lock.hcl") { Remove-Item -Force "terraform-aws/.terraform.lock.hcl" }
if (Test-Path "terraform-aws/terraform.tfstate") { Remove-Item -Force "terraform-aws/terraform.tfstate*" }

Write-Host "`n🎉 JANITOR PROTOCOL COMPLETE. The environment is scrubbed." -ForegroundColor Green