# 01. IAM - Governance

#### What is IAM?

IAM (Identity and Access Management) is the AWS service that controls **who** can access an AWS account and **what** they are allowed to do. Every request to AWS, whether from the console, the CLI or a tool like Terraform, is checked by IAM before it is executed. IAM is free and global, so identities and rules created once apply in every region.

```text
                 AWS ACCOUNT
                     |
                    IAM
                     |
        ┌────────────┼────────────┐
        ↓            ↓            ↓
      USER         GROUP         ROLE
        |            |            |
        └────────────┼────────────┘
                     ↓
                  POLICY
                     ↓
          "What are you allowed to do?"
```

**Problem IAM solves.** A single AWS account is shared by many people and programs. Without IAM, everyone would have full access to everything. IAM lets each identity get only the access it needs:

```text
Developer A → can use S3
Developer B → can use EC2
Developer C → can only view resources
Admin       → can do everything
```

IAM answers two questions:

```text
WHO are you?        → Identity   (User, Role)
WHAT can you do?    → Permission (Policy)
```

#### Users

An IAM user is an identity for one person or one application. Each user has its own credentials:

| Credential | Used for |
| :--- | :--- |
| Username and password | AWS Management Console |
| Access Key ID and Secret Access Key | AWS CLI, SDKs, Terraform |

When `aws configure` is run, the access key pair entered belongs to an IAM user. From that point every CLI and Terraform call is made as that user.

The root user, created with the account email, has unrestricted access and should not be used for daily work. It should be protected with MFA and used only for account level tasks.

> User = a long term identity for a person or an application.

#### Groups

A group is a collection of users. Policies are attached to the group, and every user in the group inherits them. This avoids attaching the same policies to many users one by one.

```text
Developers (group)            ReadOnly (group)
├── Aryen                     └── Auditor
├── Rahul
└── Priya
     ↓                              ↓
S3 and EC2 policies           ViewOnly policy
```

Rules:

* A group contains users only. It cannot contain roles or other groups.
* A group cannot be used to log in. It is only a way to manage permissions.
* A user can belong to several groups.

> Group = a set of users that share the same permissions.

#### Roles

A role is an identity with permissions but **no permanent credentials**. An AWS service, an application or a user *assumes* the role and receives temporary credentials that expire automatically (by default after one hour).

The problem roles solve:

```text
Without a role                      With a role
EC2                                 EC2
 | access key stored on disk         ↓ assumes
 ↓                                  IAM Role → Policy
S3                                   ↓
                                    S3 (temporary credentials)
```

Storing a permanent access key on a server is dangerous because anyone who gets into the server gets the key. A role removes the stored key completely.

Roles are used when:

* An EC2 instance needs to read or write S3.
* A Lambda function needs to access DynamoDB.
* A CI/CD pipeline needs to deploy to AWS.
* A user in one AWS account needs access to another account (cross account access).
* A user needs elevated permissions for a short time.

**User vs Role**

| | User | Role |
| :--- | :--- | :--- |
| Represents | A person or application | A job that can be taken on temporarily |
| Credentials | Permanent (password, access keys) | Temporary, issued when assumed |
| Typical use | Humans | EC2, Lambda, ECS, pipelines, cross account |

> Role = an identity that is assumed temporarily to get permissions.

#### Policies

A policy is a JSON document that defines permissions. It is attached to users, groups or roles.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

Every statement has three main parts:

| Part | Meaning | Example |
| :--- | :--- | :--- |
| Effect | Allow or Deny | `Allow` |
| Action | The AWS API operation | `s3:GetObject`, `ec2:StartInstances` |
| Resource | The ARN the statement applies to | `arn:aws:s3:::my-bucket/*` |

Read as a sentence: *Allow s3:GetObject on my-bucket* means "this identity may read objects from my-bucket".

Types of policies:

* **AWS managed** policies are written by AWS, for example `AmazonS3ReadOnlyAccess` or `AdministratorAccess`.
* **Customer managed** policies are written by the account owner for exact control.
* **Inline** policies are embedded in one user, group or role and are not reusable.

> Policy = a JSON document that lists what actions are allowed or denied on which resources.

#### Permissions

Permissions are the effective rights an identity ends up with after all of its policies (its own, its groups' and any assumed role's) are combined.

A new user starts with no permissions. For every request AWS evaluates:

```text
1. Is there an explicit DENY in any policy?   → request is denied
2. Is there an ALLOW?                         → request is allowed
3. Neither                                    → denied by default
```

An explicit Deny always overrides an Allow.

Example from Task 1 of this assignment:

```text
terraform apply
   ↓
AWS credentials from `aws configure`
   ↓
IAM identifies the user
   ↓
IAM checks: is s3:CreateBucket allowed on this bucket?
   ↓
No matching Allow → AccessDenied
```

The error `not authorized to perform: s3:CreateBucket` did not mean Terraform was broken. It meant the IAM user running Terraform had no policy allowing that action.

#### Least privilege

Least privilege means granting only the permissions required for a task and nothing more.

```text
Bad      s3:*                                 full access to every bucket
Better   s3:GetObject                         read only, but every bucket
Best     s3:GetObject on arn:aws:s3:::reports/*   read only, one bucket
```

If credentials with least privilege leak, the damage is limited to that one task. The practical approach is to start with no permissions and add them as a specific action is needed.

#### IAM best practices

1. Do not use the root user for daily work. Create an IAM user and lock the root user away.
2. Enable MFA on the root user and on every user with console access.
3. Attach policies to groups, not to individual users.
4. Use roles for EC2, Lambda, ECS and CI/CD instead of access keys.
5. Apply least privilege and review permissions regularly.
6. Rotate access keys and delete keys that are no longer used.
7. Never store access keys in code, in git, in screenshots or in chat messages.
8. Enable CloudTrail so every API call is recorded with the identity that made it.

#### Common use cases

| Situation | IAM solution |
| :--- | :--- |
| Each team member needs their own login | IAM user placed in a group with the right policies |
| EC2 instance must read files from S3 | IAM role attached to the instance |
| CI/CD pipeline deploys to AWS | Limited IAM user or an OIDC role for the pipeline |
| Development account needs access to production account | Cross account role |
| Auditor must view but not change anything | User in a read only group |
| Developer needs admin access for one hour | Assume an admin role with a session limit |

#### Summary

| Concept | Meaning |
| :--- | :--- |
| User | Long term identity for a person or application |
| Group | Collection of users sharing permissions |
| Role | Identity assumed temporarily by services, users or applications |
| Policy | JSON document that allows or denies actions on resources |
| Permission | The effective rights after all policies are combined |
| Least privilege | Grant only what the task requires |

```text
User   = who I am
Group  = who I belong with
Role   = who I can temporarily become
Policy = what I can do
IAM    = the system that controls all of this
```
