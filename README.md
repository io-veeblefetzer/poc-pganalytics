# POC PG Analytics

Databases are often used by convenience over purpose. This means that
while they grow they are a handy single datastore but are serving 
different purposes and different storage types. This leads to oversized 
datastores with a lot of complexities regarding maintenance and a low 
cost-efficiency. 

What if you want to split this datastore in to hot and cold storage. The 
latter is often in the form of slow moving archival and analytical data which
can perfectly be stored in the form of a datalake. On the other hand you have
your fast moving (often real-time) data with a lot of read and write operations.

You could split the database but then you loose the convenience of the single
datastore and SQL. How do we keep that convenience but are able to split our data
and be more cost-efficient?

So we need to show a few principles:

## 1. Architecture
The hot storage is served by a classic database setup. It is the current database
and it will remain the same. So, we do not have to alter connections. In this
architecture we will slim down the current database and offload data to a datalake
structure, stored on cheap blob storage in any cloud.

Then we need to abridge both storage types into the same postgres instance. Enter
`duckdb` and pg_analytics. 

`duckdb` is a modern, embedded analytics database designed for efficient processing and querying of gigabytes of data from various sources. Unlike traditional client-server databases, `duckdb` operates within the same process as your application or notebook, eliminating network overhead and simplifying deployment.
The large advantage of `duckdb` is the fact that it can perform read and write 
operations from different sources and targets and offload data from a database onto a datalake. Furthermore, it supports partitioning. We can query tables
and dump them onto blob storage.

`duckdb` will be used to offload the data onto blob storage. 

Then, we need to make that data available again into postgres. Therefore we 
use the `pg_analytics` postgres extension. In this POC we use `paradedb` which
includes that extension. `pg_analytics` is an extension which use the foreign data
wrappers and uses ``duckdb`` under the hood. So, actually we are dumping and reading
data from external storage using the same technology!

## 2. Offloading data from hot to cold storage

Start this POC by spinning up the Minio and Postgres Server by running `docker-compose up`. The database will be loaded with some random metrics data. 

Check the `docker-compose.yml` file to connect to the postgres database `pocpg` and check the `metrics` table. Let's offload this.

First [install](https://duckdb.org/docs/installation/?version=stable&environment=cli&platform=macos&download_method=package_manager) `duckdb` on your machine, or use a SQL IDE such as datagrip. 

Then [open](http://127.0.0.1:9001) the Minio dashboard and create a bucked named `pocpg`. 

Then we can start the offloading by following this script.

```sql
-- DuckDb needs to load some addons
INSTALL postgres;
LOAD postgres;

INSTALL httpfs;
LOAD httpfs;

-- Then we attach the postgres database
ATTACH 'dbname=pocpg user=pocpg password=pocpg host=127.0.0.1' AS db (TYPE POSTGRES, READ_ONLY);

CREATE SECRET pocpg (
    TYPE S3,
    KEY_ID 'minioadmin',
    SECRET 'minioadmin',
    ENDPOINT '127.0.0.1:9000',
    URL_STYLE 'path',
    PROVIDER CREDENTIAL_CHAIN,
    CHAIN 'config',
    USE_SSL false
);

-- Copy table from postgres and map it into a single parquet file
COPY
    (select * from db.metrics)
    TO 's3://pocpg/single/metrics.parquet'
    (FORMAT PARQUET);

-- Copy the table from postgres but apply partitioning
COPY
    (select m.*, extract(year from time) as year, extract(month from time) as month from db.metrics m order by time)
    TO 's3://pocpg/hive'
    (
        FORMAT PARQUET,
        PARTITION_BY (year, month)
    );
```

Now you should see the data in the `.minio` directory on your machine and in the 
[minio dashboard](http://127.0.0.1:9001).

You can then delete the datbases and trim down the datastore.

## 3. Querying that data
Now we want that data back of course, to be used for analytics. Then connect
to the postgres database and follow this script:

```sql
-- First we create a datawrapper and server, you need to do this once
CREATE FOREIGN DATA WRAPPER parquet_wrapper
HANDLER parquet_fdw_handler VALIDATOR parquet_fdw_validator;

-- Create the foreign data server for the parquet format
CREATE SERVER parquet_server FOREIGN DATA WRAPPER parquet_wrapper;

-- Create the user mapping and provide the credentials to the bucket
CREATE USER MAPPING FOR pocpg
SERVER parquet_server
OPTIONS (
  type 'S3',
  key_id 'minioadmin',
  secret 'minioadmin',
  endpoint 'minio:9000',
  url_style 'path',
  region 'eu-west-1',
  use_ssl 'false'
);

-- Create a foreign table suffixed with _cs (cold storage)
CREATE FOREIGN TABLE metrics_cs ()
SERVER parquet_server
OPTIONS (files 's3://pocpg/single/metrics.parquet');

-- Whoohoo, you can query it!
select * from metrics_cs;

```

## Some words of caution

- Of course, cold stored data is slower than hot stored data
- If partitioning is used, smart sizing the partitions is key for query preformance

