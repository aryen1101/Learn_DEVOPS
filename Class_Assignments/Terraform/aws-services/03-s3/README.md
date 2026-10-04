# 03. S3 - Storage

#### What is S3?

S3 (Simple Storage Service) is object storage. Files are uploaded into buckets, stored redundantly across several data centres in a region, and retrieved from anywhere over HTTPS. There is no disk to size and no server to manage, and capacity is unlimited. Billing is based on storage used and requests made.

```text
          S3
           |
       BUCKET   (container with a globally unique name)
           |
    ┌──────┼──────┐
    ↓      ↓      ↓
 OBJECT  OBJECT  OBJECT   (files plus metadata)
```

S3 is not a disk that a server mounts (that is EBS). It is storage that applications read and write through an API.

**Problem S3 solves.** Storing uploads or backups on a server's own disk means the disk fills up, the data is lost if the server fails, and other servers cannot see it. S3 removes all three problems.

#### Buckets

A bucket is the top level container for objects. In Task 1 of this assignment the bucket `aryen1101` was created with Terraform.

Rules:

* The name must be unique across **all** AWS accounts, not just the owner's account.
* Names are lowercase and may contain letters, numbers, dots and hyphens, 3 to 63 characters.
* A bucket is created in one region, but its name is global.
* A new bucket is private. Nothing can read it until a policy or IAM permission allows it.

```bash
aws s3 mb s3://aryen1101 --region ap-south-1
aws s3 ls
```

> Bucket = a container for objects with a globally unique name.

#### Objects

An object is a file together with its metadata.

```text
Object
├── Key       → photos/2024/trip.jpg   (full name, including the "path")
├── Data      → the file content, 0 bytes to 5 TB
└── Metadata  → content type, size, last modified, tags
```

S3 has no real folders. The `/` characters are part of the key; the console displays them as folders for convenience.

```bash
aws s3 cp trip.jpg s3://aryen1101/photos/2024/trip.jpg
aws s3 ls s3://aryen1101/photos/2024/
aws s3 rm s3://aryen1101/photos/2024/trip.jpg
```

> Object = one file in a bucket, identified by its key.

#### Storage classes

Storage classes offer different prices depending on how often data is accessed.

| Class | Use when | Trade off |
| :--- | :--- | :--- |
| Standard | Data accessed frequently | Highest storage price, no retrieval fee |
| Intelligent-Tiering | Access pattern unknown | Small monitoring fee; AWS moves objects automatically |
| Standard-IA | Accessed about once a month, needed quickly | Lower storage price, fee per retrieval |
| One Zone-IA | Same as above, but data that can be recreated | Stored in one Availability Zone only |
| Glacier Instant / Flexible | Archives and long term backups | Very low price, retrieval takes minutes to hours |
| Glacier Deep Archive | Compliance data rarely accessed | Lowest price, retrieval up to 12 hours |

#### Versioning

With versioning enabled, S3 keeps every version of an object instead of replacing it.

```text
Versioning OFF                          Versioning ON
upload report.pdf (v1)                  upload report.pdf (v1)
upload report.pdf (v2) → v1 lost        upload report.pdf (v2) → v1 kept
delete report.pdf      → gone           delete report.pdf      → delete marker added, v1 and v2 kept
```

Versioning protects against accidental overwrites and deletions. Because all versions use storage, it is usually combined with a lifecycle rule that removes old versions.

#### Lifecycle policies

A lifecycle policy applies actions to objects automatically after a set number of days.

```text
Day 0    → stored in Standard
Day 30   → transition to Standard-IA
Day 90   → transition to Glacier
Day 365  → expire (delete)
```

Lifecycle rules keep cost down for logs, backups and old versions without manual clean up.

#### Encryption

| | Method |
| :--- | :--- |
| At rest | Enabled by default with SSE-S3 (AES-256, AWS managed key). SSE-KMS uses a customer owned KMS key and records every key use in CloudTrail. |
| In transit | HTTPS. A bucket policy can deny requests made over plain HTTP. |

In the `terraform plan -destroy` output of Task 1, the bucket showed `sse_algorithm = "AES256"`, which is the default SSE-S3 encryption.

#### Bucket policies

A bucket policy is a JSON permission document attached to the bucket. IAM policies describe what an identity may do; a bucket policy describes what may be done to this bucket, including by anonymous users.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-website-bucket/*"
    }
  ]
}
```

This policy allows anyone (`Principal: *`) to read objects, which is how a static website is served. **Block Public Access** is enabled on new buckets by default and prevents such a policy from taking effect until it is deliberately turned off.

#### Common use cases

* Backups and database dumps.
* Static website hosting (HTML, CSS, JavaScript, images).
* Application, CloudTrail and load balancer logs.
* User uploads such as images and documents.
* Data lake for analytics with Athena or Glue.
* Terraform remote state shared by a team.

#### Summary

| Concept | Meaning |
| :--- | :--- |
| Bucket | Container with a globally unique name |
| Object | File plus metadata, identified by its key |
| Storage class | Price tier based on access frequency |
| Versioning | Keeps every version of an object |
| Lifecycle policy | Automatic transition or deletion after N days |
| Encryption | SSE-S3 by default at rest, HTTPS in transit |
| Bucket policy | JSON access rules attached to the bucket |

```text
Bucket     = the drawer
Object     = the file inside
Class      = how far away the drawer is
Versioning = keep old copies
Lifecycle  = automatic clean up
Policy     = who may open the drawer
```
