# terraform/cognito.tf

# 1. Create the User Pool (The Database of Users)
resource "aws_cognito_user_pool" "pool" {
  name = "project-a-user-pool"

  # We want users to log in with their email
  alias_attributes         = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

# 2. Create the App Client (Allows your Backend/Frontend to talk to Cognito)
resource "aws_cognito_user_pool_client" "client" {
  name         = "project-a-app-client"
  user_pool_id = aws_cognito_user_pool.pool.id

  # Security: No secret needed for typical frontend/SPA usage
  generate_secret = false 
  
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# 3. Create the Admin Group
resource "aws_cognito_user_group" "admin" {
  name         = "Admin"
  user_pool_id = aws_cognito_user_pool.pool.id
  description  = "Admin group for Project A dashboard"
}