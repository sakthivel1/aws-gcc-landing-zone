# GCC-Compliant AWS Workload — Complete Beginner Guide

## What You Are Building

```
Internet → WAF → ALB (TLS) → ECS Fargate (Private Subnet) → ECR (Container Images)
                                      ↑
                           CI/CD Pipeline (GitHub Actions)
                                      ↑
                           Terraform (Infrastructure as Code)
```

A secure, government-grade containerised microservice on AWS with:
- **Terraform** manages all AWS infrastructure (VPC, ECS, ALB, IAM, KMS, etc.)
- **GitHub Actions** automates build → scan → deploy pipeline
- **ECS Fargate** runs your container (no servers to manage)
- **ALB + ACM** handles HTTPS/TLS termination
- **WAF** blocks common web attacks

---

## STEP 0 — Prerequisites (Install These First)

### On your local machine:

```bash
# 1. Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version   # should print: aws-cli/2.x.x

# 2. Install Terraform
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip && sudo mv terraform /usr/local/bin/
terraform --version   # should print: Terraform v1.7.0

# 3. Install Docker
sudo apt-get update && sudo apt-get install -y docker.io
sudo systemctl start docker
docker --version   # should print: Docker version 24.x.x

# 4. Install tflint (Terraform linter)
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --version

# 5. Install Trivy (container scanner)
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy -y
trivy --version

# 6. Install Checkov (policy scanner)
pip3 install checkov
checkov --version
```

---

## STEP 1 — AWS Account Setup

### 1.1 Create IAM User for Terraform

```
1. Log into AWS Console → IAM → Users → Create user
2. Username: terraform-deployer
3. Attach policy: AdministratorAccess (for initial setup only)
4. Create access key → Download CSV (keep this safe!)
```

### 1.2 Configure AWS CLI

```bash
aws configure
# AWS Access Key ID: (paste from CSV)
# AWS Secret Access Key: (paste from CSV)
# Default region: ap-southeast-1   ← Singapore (closest GCC region)
# Default output format: json

# Verify it works:
aws sts get-caller-identity
```

---

## STEP 2 — Bootstrap Terraform State (Run Once)

> Terraform needs an S3 bucket to store its state file remotely so teams can share it.

```bash
cd infra/bootstrap

# Edit bootstrap/main.tf — change ONLY this line:
# bucket_name = "gcc-tfstate-YOUR-ACCOUNT-ID"
# Get your account ID: aws sts get-caller-identity --query Account --output text

terraform init
terraform plan    # Review what will be created
terraform apply   # Type "yes" when prompted
```

This creates:
- S3 bucket (encrypted, versioned, no public access)
- DynamoDB table (state locking — prevents two people running Terraform at once)

---

## STEP 3 — Set Up GitHub Repository

```
1. Create a new GitHub repo: my-gcc-project
2. Push this entire folder to it:
   git init
   git add .
   git commit -m "Initial GCC project"
   git remote add origin https://github.com/YOUR-USERNAME/my-gcc-project.git
   git push -u origin main
```

### Add GitHub Secrets (Settings → Secrets → Actions):

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_REGION` | `ap-southeast-1` |
| `AWS_ACCOUNT_ID` | Your 12-digit account ID |

---

## STEP 4 — Deploy Infrastructure

```bash
cd infra/environments/dev

# Edit terraform.tfvars:
# account_id = "123456789012"   ← your real account ID
# domain_name = "dev.yourdomain.gov.sg"  ← your domain

terraform init
terraform plan -out=tfplan        # Review the plan
terraform apply tfplan            # Deploy (~10-15 minutes)
```

---

## STEP 5 — Build & Push Container (CI/CD does this automatically)

```bash
# Manual test first:
cd app
docker build -t gcc-app .
docker run -p 8080:80 gcc-app    # Visit http://localhost:8080

# The pipeline will do this automatically on every git push to main
```

---

## STEP 6 — Trigger the Pipeline

```bash
git add .
git commit -m "Deploy my app"
git push origin main
# Go to GitHub → Actions tab → watch the pipeline run
```

Pipeline stages:
1. ✅ Lint & validate Terraform
2. ✅ Build Docker image
3. ✅ Trivy container scan
4. ✅ Checkov policy scan
5. ⏸️ **Manual approval gate** (you click "Approve" in GitHub)
6. ✅ Terraform apply
7. ✅ Deploy to ECS (blue/green)

---

## STEP 7 — Verify Everything Works

```bash
# Get the ALB DNS name
terraform -chdir=infra/environments/dev output alb_dns_name

# Test the endpoint
curl https://YOUR-ALB-DNS-NAME/health

# Check ECS service is running
aws ecs list-tasks --cluster gcc-cluster --region ap-southeast-1
```

---

## Folder Structure

```
.
├── README.md                    ← You are here
├── infra/
│   ├── bootstrap/               ← Run ONCE to create S3 state bucket
│   ├── modules/                 ← Reusable Terraform building blocks
│   │   ├── vpc/                 ← Network (VPC, subnets, NAT)
│   │   ├── security-groups/     ← Firewall rules
│   │   ├── iam/                 ← Permissions
│   │   ├── kms/                 ← Encryption keys
│   │   ├── cloudwatch/          ← Logs & alarms
│   │   ├── ecr/                 ← Container registry
│   │   ├── ecs/                 ← Container runtime
│   │   ├── alb/                 ← Load balancer
│   │   ├── waf/                 ← Web firewall
│   │   └── s3-state/            ← State bucket (used by bootstrap)
│   └── environments/
│       └── dev/                 ← Dev environment config
├── app/                         ← Your application + Dockerfile
├── pipelines/                   ← GitHub Actions CI/CD config
└── docs/                        ← Architecture + compliance docs
```
