☁️ Cloudhelden Project A - AI Feedback Analyzer
📖 Project Overview
The AI Feedback Analyzer is a highly scalable, full-stack cloud application deployed on Amazon Web Services (AWS). It provides a user-facing web interface to collect customer feedback, analyzes the text's sentiment (Positive, Negative, or Neutral/Mixed) using AWS Comprehend, and securely stores the data in an Amazon RDS PostgreSQL database. It also includes an admin dashboard secured by AWS Cognito for reviewing feedback.

This project demonstrates a complete end-to-end cloud architecture: from local Node.js/HTML development and automated testing to containerization, CI/CD automation, Infrastructure as Code (IaC), and Kubernetes orchestration.

🏗️ Tech Stack
Frontend: HTML5, Vanilla JavaScript, Bootstrap 5

Backend: Node.js, Express.js, pg (PostgreSQL client), AWS SDK v3

Testing: Jest (app.test.js, logic.test.js)

AI/Machine Learning: AWS Comprehend (Sentiment & Key Phrase Analysis)

Database: Amazon RDS PostgreSQL 16

Authentication: Amazon Cognito (Admin Login)

Containerization: Docker, Amazon ECR

Orchestration: Kubernetes (AWS EKS), AWS ALB Ingress Controller

Infrastructure as Code: Terraform (AWS Provider v5.0)

CI/CD: GitHub Actions

📂 Project Structure
Plaintext
cloudhelden-project-a/
├── backend/
│   ├── Dockerfile               # Linux-based container build instructions
│   ├── app.test.js              # Integration tests for the Express server
│   ├── logic.js                 # Core business logic for feedback processing
│   ├── logic.test.js            # Unit tests for the business logic
│   ├── package-lock.json        # Locked dependency versions
│   ├── package.json             # Node.js dependencies and test scripts
│   └── server.js                # Main Express API routing and DB/AI connections
├── frontend/
│   ├── Dockerfile               # Nginx container build for the static site
│   ├── admin.html               # Admin dashboard displaying database records
│   ├── index.html               # User-facing feedback submission page
│   └── login.html               # AWS Cognito login portal for the admin panel
├── iam_policy.json              # IAM roles and permissions for deployment
├── k8s/
│   ├── backend-deployment.yaml  # K8s Deployment & Service (injects DB env vars)
│   ├── configmap.yaml           # Non-sensitive configuration variables
│   ├── frontend-deployment.yaml # K8s Deployment & Service for frontend
│   ├── ingress.yaml             # Application Load Balancer routing rules
│   └── secret.yaml              # Base64 encoded secure DB credentials
└── terraform/
    ├── cognito.tf               # Provisions AWS Cognito User Pools
    ├── main.tf                  # Provisions VPC, Subnets, EKS, and RDS
    ├── outputs.tf               # Exports crucial IDs and endpoints (e.g., RDS URL)
    └── variables.tf             # Parameterized infrastructure variables
(Note: Hidden files like .dockerignore and .env are also utilized to ensure secure and architecture-agnostic cloud builds).

🚀 Step-by-Step Deployment Guide
1. Provision Infrastructure (Terraform)
The infrastructure is fully defined in the terraform/ directory. It provisions a custom VPC, EKS Cluster, RDS PostgreSQL instance, and Cognito User Pools.

Bash
cd terraform
terraform init
terraform apply -auto-approve
Note: The EKS nodes are placed in public subnets with enable_public_ip = true to allow outbound internet access to AWS Comprehend without incurring NAT Gateway costs.

2. CI/CD Pipeline (GitHub Actions)
Pushing to the main branch triggers a GitHub Actions workflow that:

Authenticates with AWS using temporary SSO/OIDC credentials.

Runs the Jest testing suite (app.test.js, logic.test.js).

Builds pure Linux (AMD64) Docker images for both the frontend and backend.

Pushes the images to Amazon Elastic Container Registry (ECR).

3. Kubernetes Deployment
Once the infrastructure is up and images are in ECR, deploy the Kubernetes resources:

Bash
# Apply configuration and secure credentials first
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Deploy Frontend and Backend microservices
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/backend-deployment.yaml

# Expose the application to the internet via AWS ALB
kubectl apply -f k8s/ingress.yaml
Retrieve the public Load Balancer URL to access the application:

Bash
kubectl get ingress
🌟 Application Features
Real-time AI Analysis: Users submit feedback via index.html. The backend forwards the text to AWS Comprehend in eu-central-1 (Frankfurt) for NLP sentiment analysis.

Persistent Storage: Results are saved to the RDS PostgreSQL database via a secure, internal VPC connection.

Secured Admin Dashboard: Administrators authenticate via AWS Cognito on login.html before accessing admin.html to view aggregated sentiment statistics.

🧠 Challenges & Lessons Learned
Building and deploying this distributed system involved debugging several complex, real-world cloud architecture issues:

Architecture Mismatches (ARM64 vs AMD64): * Issue: Docker images built locally on a Mac M-series chip caused an Exec format error crash loop (CrashLoopBackOff) on the AWS EKS t3.small nodes (which run AMD64).

Fix: Implemented a .dockerignore file to prevent local Mac node_modules from being copied, delegating the clean build process entirely to a Linux-based GitHub Actions runner.

Database Authentication & VPC Security: * Issue: Connecting the EKS backend pods to the RDS instance resulted in ClientAuthentication and auth_failed FATAL errors.

Fix: Aligned the Terraform initialization variables with the Kubernetes backend-deployment.yaml environment variables. Additionally, passed PGSSLMODE='no-verify' to bypass strict RDS SSL certificate validation for internal Kubernetes-to-RDS traffic.

Cross-Region AI Service Availability: * Issue: The infrastructure was deployed in Stockholm (eu-north-1), but AWS Comprehend is not supported in that region, causing backend API crashes.

Fix: Hardcoded the AWS SDK client inside server.js to point specifically to Frankfurt (eu-central-1), allowing cross-region AI inference while keeping the compute and database local.

EKS Node Internet Access (ENOTFOUND):

Issue: Backend pods could not resolve the AWS Comprehend API DNS.

Fix: Discovered that EKS nodes in a public subnet without a NAT Gateway require public IPs to route outbound internet traffic. Updated the Terraform node group configuration with enable_public_ip = true.

🧹 Teardown & Cleanup
To prevent ongoing AWS charges, destroy the environment in this specific order:

Bash
# 1. Delete Kubernetes resources (removes the AWS Load Balancer)
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/frontend-deployment.yaml
kubectl delete -f k8s/backend-deployment.yaml

# 2. Destroy infrastructure
cd terraform
terraform destroy -auto-approve
