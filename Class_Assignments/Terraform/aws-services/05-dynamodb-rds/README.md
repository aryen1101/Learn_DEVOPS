# 05. DynamoDB & RDS - Database Services

AWS provides two different kinds of managed database. **DynamoDB** is a NoSQL database built for very high scale and fast key based access. **RDS** is a managed relational database that runs familiar SQL engines. In both cases AWS operates the underlying servers, applies patches, takes backups and handles failover.

```text
              DATABASES IN AWS
                     |
        ┌────────────┴────────────┐
        ↓                         ↓
    DynamoDB                     RDS
    NoSQL                        SQL
    key → item                   tables, rows, joins
    serverless                   managed database server
```

---

#### DynamoDB

#### NoSQL

DynamoDB is a key value and document database. Unlike a relational database it has no fixed schema and no joins. Items in the same table can have different attributes. Data is modelled around how the application reads it rather than normalised into many tables. In return DynamoDB delivers single digit millisecond latency at any scale, scales automatically, and requires no server management.

> DynamoDB = a serverless key value store that returns an item by its key in milliseconds at any scale.

#### Tables

A table is the only structural object in DynamoDB; there is no database above it. Each table has a name, a primary key, and a capacity mode:

| Mode | Billing | Suitable for |
| :--- | :--- | :--- |
| On demand | Per request | Unpredictable or spiky traffic |
| Provisioned | Fixed reads and writes per second | Steady, predictable traffic |

#### Items

An item is one record in a table, comparable to a row in SQL. It is stored as a JSON like document and can be up to 400 KB.

```json
{
  "user_id":  "u123",
  "order_id": "2024-06-01#001",
  "total":    49.99,
  "status":   "shipped"
}
```

#### Attributes

Attributes are the fields inside an item, such as `total` and `status` above. Apart from the key attributes, each item may have its own set of attributes. Adding a new attribute requires no schema change.

```text
Table     → the whole collection          (Orders)
Item      → one record                    (one order)
Attribute → one field inside the record   (total, status)
```

#### Partition key

The partition key is the required part of the primary key. DynamoDB hashes it to decide which physical partition stores the item. A good partition key has many distinct values so that data and traffic spread evenly.

```text
user_id  → millions of distinct values → even spread → good
country  → about 200 values → a few partitions get all the load → poor
```

If the table has only a partition key, the value must be unique for every item.

#### Sort key

The sort key is optional. Together with the partition key it forms a composite primary key, and the pair must be unique. Items sharing a partition key are stored together in sort key order, which makes range queries efficient.

| Partition key | Sort key | Query enabled |
| :--- | :--- | :--- |
| user_id | order_date | All orders of one user between two dates |
| device_id | timestamp | Readings of one device for the last hour |
| customer_id | record_type | Several record types for one customer in one table |

#### DynamoDB use cases

* Shopping carts and user sessions.
* Gaming leaderboards and player profiles.
* IoT and clickstream data with millions of writes per second.
* Serverless backends with Lambda and API Gateway.
* Any workload that needs fast lookup by key at very high scale.

---

#### RDS

#### Relational database

RDS (Relational Database Service) runs a managed SQL database. Data is stored in tables with defined columns, tables are linked by foreign keys, and SQL supports joins and transactions. AWS installs and patches the engine, takes backups and provides failover, while the application connects with the same drivers and tools used for a self hosted database.

```text
Customer responsibility          AWS responsibility
Schema design                    Install and patch the engine
SQL queries                      Automated backups
Application connection           Replace failed hardware
                                 Failover (Multi-AZ)
```

> RDS = a managed relational database server.

#### Supported engines

| Engine | Notes |
| :--- | :--- |
| MySQL | Most widely used open source engine |
| PostgreSQL | Feature rich, popular for new applications |
| MariaDB | Community fork of MySQL |
| Oracle | Enterprise, licence included or bring your own |
| Microsoft SQL Server | Windows based workloads |
| Amazon Aurora | AWS built engine compatible with MySQL and PostgreSQL, higher performance and automatic storage scaling |

#### DB instances

A DB instance is the database server itself. When creating one the following are chosen:

```text
Engine and version   → PostgreSQL 16
Instance class       → db.t3.micro (free tier) or db.r6g.large (memory optimised)
Storage              → 20 GB gp3 SSD
Network              → VPC and private subnets
```

The instance is reached through an endpoint such as `mydb.abc123.ap-south-1.rds.amazonaws.com` on the engine's port. There is no SSH access to the underlying server.

#### Security

| Measure | Purpose |
| :--- | :--- |
| Private subnet, no public IP | Database is not reachable from the internet |
| Security group allowing the DB port only from the application tier's security group | Only application servers can connect |
| Encryption at rest with KMS, enabled at creation | Data on disk is encrypted; cannot be enabled later without a snapshot restore |
| SSL/TLS enforced | Data in transit is encrypted |
| Credentials in Secrets Manager or IAM database authentication | No passwords in application code |

#### Backups

| Type | Behaviour |
| :--- | :--- |
| Automated backups | Daily snapshot plus transaction logs; restore to any second within the retention period of 1 to 35 days |
| Manual snapshots | Taken on demand, kept until deleted; recommended before major changes |

A restore always creates a new DB instance with a new endpoint. The existing instance is never overwritten.

#### Multi-AZ

Multi-AZ keeps a synchronous standby copy of the database in a second Availability Zone.

```text
Primary (AZ-a)  ══ synchronous replication ══►  Standby (AZ-b)

Primary fails
   ↓
AWS switches the same endpoint to the standby (about one minute)
   ↓
Application reconnects without configuration changes
```

Multi-AZ provides high availability. The standby cannot serve read traffic.

#### Read replicas

A read replica is an asynchronous copy of the database that applications can read from. Writes go to the primary only and are replicated to the replicas with a small delay. Several replicas can exist, including in other regions, and a replica can be promoted to a standalone database.

```text
Primary ── async ──► Replica 1  ◄── reporting queries
        ── async ──► Replica 2  ◄── analytics queries
```

| | Multi-AZ | Read replica |
| :--- | :--- | :--- |
| Purpose | Failover and availability | Scaling read traffic |
| Replication | Synchronous | Asynchronous |
| Readable by application | No | Yes |
| Location | Same region, different AZ | Same or different region |

#### RDS use cases

* Web and mobile application backends that require transactions.
* E-commerce orders, payments and inventory.
* Applications already built on MySQL or PostgreSQL.
* Reporting and business intelligence on relational data.

---

#### Choosing between DynamoDB and RDS

| Requirement | DynamoDB | RDS |
| :--- | :--- | :--- |
| Joins, transactions, complex SQL | No | Yes |
| Key lookups at very high scale | Yes | Possible but costly |
| Frequent schema changes | Easy | Requires migrations |
| Serverless, pay per request | Yes | Aurora Serverless only |
| Existing SQL application | No | Yes |

#### Summary

| Concept | Meaning |
| :--- | :--- |
| DynamoDB | Serverless NoSQL key value database |
| Table / Item / Attribute | Collection / record / field |
| Partition key | Required key that decides where an item is stored |
| Sort key | Optional key that orders items within a partition |
| RDS | Managed relational SQL database |
| DB instance | The database server, chosen by engine and size |
| Multi-AZ | Synchronous standby for failover |
| Read replica | Asynchronous copy for read scaling |

```text
DynamoDB      = locker with a key, instant, unlimited lockers
RDS           = filing cabinet with labelled drawers, maintained by AWS
Partition key = locker number
Sort key      = order inside the locker
Multi-AZ      = spare cabinet in another room
Read replica  = photocopy for people who only read
```
