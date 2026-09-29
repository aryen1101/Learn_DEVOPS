# 03. S3 - Storage

S3 (Simple Storage Service) is object storage. I upload files into buckets and AWS keeps them safe, copies them across several data centres, and serves them over HTTPS from anywhere. There is no disk to manage and no limit on how much I can store. I pay for the space used and the requests made. It is not a file system for a server, it is a very large and very reliable cloud drive that programs talk to through an API.

**Buckets.** A bucket is the top level container. The name must be unique across all of AWS, not just my account, which is why a name like `aryen1101` works but `test` never will. Names are lowercase with letters, numbers and hyphens. A bucket lives in one region and is private by default.

**Objects.** An object is a file plus its metadata. Each object has a key, which is its full name including any folder path such as `photos/2024/trip.jpg`. S3 has no real folders, the slashes are just part of the key. An object can be from 0 bytes up to 5 TB.

**Storage classes.** Storage classes let me pay less for data I touch less often. Standard is for data used all the time. Intelligent-Tiering lets AWS move objects for me. Standard-IA and One Zone-IA are cheaper for data used maybe once a month. Glacier and Glacier Deep Archive are very cheap for archives but take minutes to hours to retrieve.

**Versioning.** With versioning on, S3 keeps every version of an object. If I overwrite or delete a file by mistake, the old version is still there and I can restore it. Deleting only adds a delete marker on top. It uses more storage, so it is usually paired with a lifecycle rule to remove old versions.

**Lifecycle policies.** A lifecycle rule tells S3 to do something automatically after a number of days. For logs it might be: keep in Standard for 30 days, move to Standard-IA, move to Glacier at 90 days, delete after a year. Nobody has to remember to clean up.

**Encryption.** Every new object is encrypted at rest by default with SSE-S3, where AWS manages the key. In my destroy plan this showed up as `sse_algorithm = "AES256"`. I can choose SSE-KMS instead to use my own KMS key and get an audit trail. Data in transit goes over HTTPS.

**Bucket policies.** A bucket policy is a JSON document attached to the bucket that says who can do what with it, and it works together with IAM. A common one gives everyone `s3:GetObject` for a static website. Block Public Access is on by default and stops such policies from working until I turn it off on purpose, which is a good safety net.

**Common use cases.** Backups and database dumps, hosting a static website, application and CloudTrail logs, user uploads like images and documents, a data lake for analytics, and Terraform remote state so a team shares one state file.
