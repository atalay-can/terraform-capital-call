****What it deploys****

**Networking**

- A dedicated VPC with public and private subnets across two availability zones
- A NAT Gateway allowing private resources to reach the internet securely
- Route tables keeping the RDS instance isolated from public access

**Database**

- A PostgreSQL 16 RDS instance deployed into private subnets
- Encrypted storage at rest, SSL enforced in transit
- Automated daily backups with a 7-day retention window
- Enhanced Monitoring and Performance Insights enabled
- Storage autoscaling up to 100GB

**Security**

- Master credentials auto-generated and stored in AWS Secrets Manager
- Security groups locking down database access to within the VPC only
- RDS never publicly accessible


**Schema**

- Seven tables covering fund, investor, commitment, capital_call, capital_call_allocation, payment_instruction, and payment
- UUID primary keys, ENUM types, CHECK constraints, and auto-updating updated_at triggers
- Indexes on all foreign keys and frequently queried columns



**Project Structure**

terraform-capital-call/

├── main.tf               # Root module — wires everything together

├── variables.tf          # All configurable inputs

├── outputs.tf            # Key outputs (endpoint, secret ARN, etc.)

├── versions.tf           # Terraform and provider version constraints

├── modules/

│   ├── networking/       # VPC, subnets, NAT, route tables

│   └── rds/              # RDS instance, security group, parameter group

└── sql/
    └── schema.sql        # PostgreSQL schema — run after provisioning


**Requirements**
- Terraform >= 1.5.0
- AWS CLI configured with appropriate permissions
- PostgreSQL client to run schema.sql post-deploy

The default configuration deploys to eu-central-1 (Frankfurt) on a db.t3.micro instance, suitable for development. For production, enable db_multi_az, db_deletion_protection, and upgrade the instance class.
