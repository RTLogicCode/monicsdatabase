# Overview

This directory contains several scripts that can be used to create a centralized Monics storage system
within PostgreSQL.

# Conventions

1. The names of the tables will be all lower case.
2. The names of the tables will start with **tbl_**. This is different from the standard Monics definitions
that start with **tbl**. The underscore is added for readability in the name.
3. There will be underscore characters to denote word breaks in DB object names. This is for readability.

# Key Table

In order to reduce the size of indexes on tables, there will be one table to act as a table of *keys* that
all other tables can reference with foreign keys. Those table indexes will be significantly smaller than
maintaining the same structure as Monics ring buffer tables. Additionally, that table won't grow in record
count by any *big data* type means. It will hover around a thousand during archival periods.

# Partitioning

Our centralized structure uses PostgreSQL partitioning approach. At present, only PostgreSQL 9.6+ is
available within Amazon Web Services, so it relies on an older technique (i.e. does not use **PARTITION**
keyword). The newer technique is only available in PostgreSQL 10.0+.

Master tables are created to contain some key data, or filter criteria data, and a JSON column is
added to store all the actual Monics data. This is to *future proof* the structures from underlying
Monics ring buffer changes. Some tables, however, will contain actual columns of data; but his more
by exception than by rule.

We create partition tables through PostgreSQL table inheritance based on year and month of data collection.
Appropriate year and month constraints are part of the partition table definition. A trigger
is created on the master table to ensure records are inserted into the appropriate partition table. This
is the older method of partitioning (i.e. not using the **PARTITION** keyword).

Every master table will also have an *other* table. This is considered a holding table for data that
is outside of the current retention policy time period. The table will be periodically scanned for
data and a determination will be made on what to do with that data, if anything. These tables exist
to have some place to put records when partitions are being maintained, or during the processing of
erroneous data. These tables will be *disinherited* right after creation in order to prevent
table scans in those tables during queries.

> It is important to note that primary and foreign keys, along with indexes, are not
> inherited between a master and child table. Therefore, they are not defined on the
> master table, and must be explicitly defined on the partition tables.

## Master Definition

Master tables will resemble the following structure. This is the rule, but again, there may be exceptions
to the rule.

```sql
CREATE TABLE IF NOT EXISTS <table name> (
  rec_id BIGSERIAL,
  rec_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rec_utimestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  par_rec_id BIGINT NOT NULL,
  RecIndex BIGINT NOT NULL,
  Time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  Data JSONB NOT NULL
);
```

| Column             | Description                                                                                                   |
| -------------------|---------------------------------------------------------------------------------------------------------------|
| `rec_id`           | An auto number column to use for primary keys.                                                                |
| `rec_timestamp`    | A timestamp that identifies when the record was created.                                                      |
| `rec_utimestamp`   | A timestamp that identifies when the record was created. Records should not be modified, its just convention. |
| `key_rec_id`       | A column in order to reference the *keys* table.                                                              |
| `RecIndex`         | The Monics **RecIndex**, useful in correlating data across multiple master tables.                            |
| `Time`             | The Monics **Time** column. Also useful in correlating data across multiple master tables.                    |
| `Data`             | A JSON representation of the Monics data.                                                                     |

Inserts and queries should be accomplished on the master tables. If constraints are defined appropriately,
and they are part of the **WHERE** clause, they query analyzer will only look in the correct partition tables. A trigger will
be defined on the master table that will ensure data gets into the proper partition table. The trigger will always exist and will
be replaces as needed depending on the retention cycles. For instance, we don't need to check every potential date range if
we're only working against the past 3 months.

The master table should *expose* columns when its relevant to structuring the partitions. For instance, some of the Monics
data will contain **ChannelType**. This can be useful to create different partitions. In the case of SA trace data, it will
be used (one of the exceptions to the rule).

## Partition Definition

A partition table will resemble the following structure. The partition table name will be that of the
master with **_y<4-digit year>m<2-digit month>** as a suffix. This is the rule, but again, there may be
exceptions to the rule.

```sql
CREATE TABLE <table name>_y2018m01 (
  CONSTRAINT pk_<table name>_y2018m01 PRIMARY KEY ( rec_id ),
  CONSTRAINT fk_<table name>_y2018m01 FOREIGN KEY ( par_rec_id )
    REFERENCES tbl_keys ( rec_id ) 
    ON UPDATE CASCADE ON DELETE CASCADE,
  CHECK ( Time >= DATE '2018-01-01' AND Time < DATE '2018-02-01' )
) INHERITS ( <table name> );
```

The **CHECK** constraint on the **Time** column prevents records from being inserted that are not in the
month of January.

The partition table will also contains the following indexes.

```sql
CREATE INDEX idx_<table name>_y2018m01_par_rec_id ON <table name>_y2018m01 ( par_rec_id ASC );
CREATE INDEX idx_<table name>_y2018m01_time ON <table name>_y2018m01 ( Time ASC );
CREATE INDEX idx_<table name>_y2018m01_data ON <table name>_y2018m01 USING GIN ( Data );
CREATE INDEX idx_<table name>_y2018m01_skey ON <table name>_y2018m01 ( par_rec_id ASC, Time ASC );
```

The **GIN** index defined on the **Data** column will allow the JSON data to be filtered as desired. For instance, the
**BitErrorRate** can be included in a **WHERE** clause, it would resemble:

```sql
SELECT * FROM <table name> WHERE Data->>'BitErrorRate' > 1.0;
```

## Other Partition



## Partition Trigger

Every master table will have an associated **BEFORE INSERT** trigger. The trigger has the responsibility of putting
data into the appropriate partition table. If it doesn't match any known partitions, the data should be written to
the *other* table (represents the default insert table). No data should be put directly into the master table. This
ensures a quick scan of an empty table during *constraint exclusion*.

The partitioning trigger will resemble the following:

```sql
CREATE OR REPLACE FUNCTION <table name>_bins_func() RETURNS TRIGGER AS $$
BEGIN
  IF ( NEW.Time >= DATE '2018-01-01' AND NEW.TIME < DATE '2018-02-01' AND inherits_from('<table name>', '<table name>_y2018m01') ) THEN
    INSERT INTO <table name>_y2018m01 VALUES ( NEW.* );
  ELSIF ( NEW.Time >= DATE '2018-02-01' AND NEW.TIME < DATE '2018-03-01' AND inherits_from('<table name>', '<table name>_y2018m01') ) THEN
    INSERT INTO <table name>_y2018m02 VALUES ( NEW.* );
  ELSE
    INSERT INTO <table name>_other VALUES ( NEW.* );
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';
```
The trigger should contain additional constraint checks that match the partition design. For instance, if **ChanneType** was
included as part of the partition scheme, it should be checked as well.

Note the function **inherits_from** ... this should be part of the **IF** expression. As part of partition maintenance, a
partition will be *disinherited* from the master. This check will ensure that insert don't occur on a partition that is
being archived and eventually removed.

## Partition Maintenance

The partition tables need to be maintained on a regular basis. This is based on some established policy
retention of data. When data is deemed *archivable*, a partition table is *disinherited*, cleaned
up (vacuumed, clustered, etc.), and exported to text files. The partition table is then truncated and
deleted.

