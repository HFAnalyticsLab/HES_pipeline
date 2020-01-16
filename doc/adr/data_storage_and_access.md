# How will data be stored and accessed?

## Context

The raw HES data is large, complex, unweildly and potentially dirty. A way to 
clean, store and later easily access the data for analysis required, which means
that repeated cleaning and prep of the raw data is avoided.

There are multiple datasets (with different variables), which once cleaned, will
be accompanied by additional derived variables, and additional derived datasets.

## Decision

The raw data will be read into a SQLite database through R. R is The Health
Foundation's open-source language of choice, and is well equiped to 
handle later analysis of said data. An SQLite database is not stored in memory,
avoiding holding very large datasets an R session. It is a standard database
format which can be easily queried with SQL which can in turn be written within
most other common languagses, including R.

In an SQLite database the database consistents of all the data, and within that
there are tables; here each table corresponds to a HES dataset or a derived 
dataset.

## Status

Decided

## Consequences

Some additional learning is required in how to query an SQLite database. This 
requires some additional documentation (to come).

An SQLite database still occupies quite a large amount of storage space.

Reading large files into R is always going to somewhat slow, but through testing
we have optimised the process using (`fread`)[link to come] from the data.table 
package, to read in the data in chunks and write directly to SQLite.