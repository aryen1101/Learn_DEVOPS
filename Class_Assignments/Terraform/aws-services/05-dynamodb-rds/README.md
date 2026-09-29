# 05. DynamoDB & RDS - Database Services

AWS gives two very different kinds of managed database. DynamoDB is NoSQL and made for huge scale with simple lookups. RDS is the classic relational database with tables, joins and SQL. In both cases AWS handles the servers, patching and backups.

**DynamoDB**

**NoSQL.** DynamoDB is a key value and document database with no fixed schema. Two items in the same table can have different fields and there are no joins. I design the table around how the app reads data, not around normalised tables. In return I get single digit millisecond speed at any size and no servers to manage.

**Tables.** A table is the only structure, there is no database above it. Each table has a name, a key, and either on demand pricing (pay per request) or provisioned capacity (fixed reads and writes per second).

**Items.** An item is one record, like a row in SQL. It is stored as JSON and can be up to 400 KB.

**Attributes.** Attributes are the fields inside an item, such as `total` or `status`. Apart from the key attributes, every item can have its own set.

**Partition key.** The partition key is required. DynamoDB hashes it to decide which physical partition stores the item, so a good partition key has many different values to spread data evenly. `user_id` is good, `country` is bad because most items would land in a few partitions.

**Sort key.** The sort key is optional. Together with the partition key it makes the full primary key. Items with the same partition key are stored side by side, ordered by the sort key, so I can ask for all orders of user `u123` from June in one query.

**Use cases.** Shopping carts and user sessions, gaming leaderboards, IoT data with millions of writes per second, serverless apps with Lambda, and anything that needs a fast key lookup at very high scale.

**RDS**

**Relational database.** RDS (Relational Database Service) runs a normal SQL database for me. Data lives in tables with fixed columns, tables link with foreign keys, and I query with SQL including joins and transactions. AWS installs it, patches it, backs it up and can fail it over. I connect with the same drivers and tools I would use on my own server.

**Supported engines.** MySQL, PostgreSQL, MariaDB, Oracle, Microsoft SQL Server, and Amazon Aurora, which is AWS's own MySQL and PostgreSQL compatible engine built for speed and scale.

**DB instances.** A DB instance is the actual database server. I choose the engine and version, the instance class such as `db.t3.micro` for free tier or `db.r6g.large` for memory heavy work, the storage type and size, and the VPC and subnets it sits in. It gets an endpoint like `mydb.abc123.ap-south-1.rds.amazonaws.com` for the app to connect to.

**Security.** Put the instance in a private subnet so it has no public IP. Use a security group that allows the database port only from the app servers' group. Turn on encryption at rest with KMS when creating it, since it cannot be added later without a restore. Force SSL, and keep the password in Secrets Manager instead of code.

**Backups.** Automated backups run daily and keep transaction logs, so I can restore to any second in the retention window of 1 to 35 days. Manual snapshots are taken when I want and kept until I delete them, which is useful before a big change. A restore always creates a new instance.

**Multi-AZ.** Multi-AZ keeps a standby copy in a second Availability Zone and every write goes to both. If the main one fails, AWS switches the endpoint to the standby in about a minute and the app does not need to change anything. It is for availability, not for extra read speed, because the standby cannot be queried.

**Read replicas.** A read replica is a copy the app can read from. Writes still go to the main instance and are copied over a little later. I can have several replicas, even in other regions, to take reporting and read heavy traffic off the main database.

**Use cases.** Web and mobile app backends that need transactions, e-commerce orders and payments, anything that already runs on MySQL or PostgreSQL and just needs to be managed, and reporting on top of relational data.
