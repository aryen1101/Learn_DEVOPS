# 01. IAM - Governance

IAM (Identity and Access Management) is the service that decides who can get into my AWS account and what they are allowed to do once inside. Every single request to AWS, whether it comes from the console, the CLI or Terraform, is checked by IAM first. It is free and it is global, so the same users and rules work in every region.

**Users.** A user is one person or one application that needs access. Each user gets their own identity with a password for the console and, if needed, access keys for the CLI and tools like Terraform. The keys I typed into `aws configure` belong to an IAM user. The root account should not be used for daily work.

**Groups.** A group is a bunch of users that share the same permissions. Instead of attaching the same policy to ten developers one by one, I attach it once to a `developers` group and add the users to it. A new team member gets everything by just joining the group.

**Roles.** A role is like a user without a permanent password or keys. Something assumes the role and gets temporary credentials that expire on their own. Roles are used when an EC2 instance needs to read S3, when Lambda needs to write to DynamoDB, or when another AWS account needs access to mine. They are safer than keys because nothing long lived is stored on the server.

**Policies.** A policy is a JSON document that says what is allowed or denied. It has three main parts: Effect (Allow or Deny), Action (the API calls, like `s3:GetObject`) and Resource (the ARN it applies to). AWS gives ready made policies such as `AmazonS3ReadOnlyAccess`, and I can write my own for exact control.

**Permissions.** Permissions are the actual rights that a user, group or role ends up with after all its policies are combined. A new user starts with nothing. When a request comes in, AWS checks for an explicit Deny first, then for an Allow, and if neither is found the request is denied. This is why my first `terraform apply` failed with AccessDenied: the user had no policy allowing `s3:CreateBucket` for that name.

**Least privilege.** Give only the permissions needed for the job and nothing extra. A backup script that uploads to one bucket should not have full S3 access, and certainly not admin. If its keys leak, the damage stays small.

**IAM best practices.** Do not use the root account, turn on MFA for root and for all users, use groups instead of attaching policies to individual users, use roles for EC2 and Lambda instead of keys, rotate keys and delete unused ones, and never put keys in code, screenshots or git. Turn on CloudTrail so there is a record of who did what.

**Common use cases.** Separate logins for each team member with the right level of access, an EC2 instance reading from S3 through a role, a CI/CD pipeline deploying with a limited user, cross account access between a dev and a prod account, and read only access for auditors.
