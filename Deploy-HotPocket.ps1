Write-Host " MICROWAVING THE HOT POCKET (Epiq IM8 Deployment)..." -ForegroundColor Cyan

# 1. Build the Foundation (VPC & ECR Vault)
Write-Host "`n[1/3] Provisioning Network and Image Vault..." -ForegroundColor Yellow
Set-Location "terraform-aws"
terraform init
terraform apply -target="aws_ecr_repository.epiq_engine" -target="module.vpc" -auto-approve

# 2. Bake and Push the Secure Container
Write-Host "`n[2/3] Building and Injecting Secure App Container..." -ForegroundColor Yellow
Set-Location ".."
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 425629232565.dkr.ecr.ap-southeast-1.amazonaws.com
docker build -t epiq-discovery-engine:latest .
docker tag epiq-discovery-engine:latest 425629232565.dkr.ecr.ap-southeast-1.amazonaws.com/epiq-discovery-engine:latest
docker push 425629232565.dkr.ecr.ap-southeast-1.amazonaws.com/epiq-discovery-engine:latest

# 3. Deploy the Fortress (Load Balancer, WAF, Fargate)
Write-Host "`n[3/3] Deploying WAF and Fargate Cluster..." -ForegroundColor Yellow
Set-Location "terraform-aws"
terraform apply -auto-approve

# 4. Serve
$ALB_URL = terraform output -raw alb_dns_name
Write-Host "`n✅ HOT POCKET READY! Access your secure environment at:" -ForegroundColor Green
Write-Host "http://$ALB_URL" -ForegroundColor White