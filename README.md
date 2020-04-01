# HES pipeline

Open-source R pipeline to clean and process patient-level Hospital Episode 
Statistics (HES) & ONS Civil Registrations data, with the aim to produce 
analysis-ready datasets for a defined programme of analyses.

#### Project Status: in progress

## Project Description

[Hospital Episode Statistics (HES)](https://digital.nhs.uk/data-and-information/data-tools-and-services/data-services/hospital-episode-statistics) is a database containing details of all hosptial admissions, A&E attendances and outpatient appointments at NHS hospitals in England.

Before it can be used for analysis, HES data requires cleaning (e.g. duplicate 
removal) and quality control as well as additional derived variables and tables. 
The complexity of HES. the large number of variables and the size of the data 
sets can makes this a challenging task.

This cleaning and processing workflow will be designed to ensure that the HES
data is processed consistently and reproducably, and that every one of our
pre-approved analysis projects work with the cleaned data sets.

## Data Source

We are planning to use HES data linked to Civil Registrations (deaths) covering
the last 10 years as well as quarterly data updated for the next three years. 
Our data application has been approved by the NHS Digital [Data Access Request 
Service [Data Access Request 
Service (DARS)](https://digital.nhs.uk/services/data-access-request-service-dars) and development of this pipeline has now 
commenced.

The data will be accessed in The Health Foundation's Secure Data Environment; a 
secure data analysis facility (accredited with the ISO27001 information security
standard, and recognised for the NHS Digital Data Security and Protection
Toolkit). No information that could directly identify a patient or other 
individual will be used.

## Documentation (work in progress)

The doc folder contains information on 
* the protocol for HES data cleaning and processing used [to be added]
* the design of the pipeline: ADR and process.md
* the [logs](doc/logging.md) that are created 
* definitions of [derived variables](doc/derived_variables.md) - to be updated
* definitions of [derived tables](doc/derived_tables.md)

Sections at the end of the README describe
* how to use the pipeline 
* how to query the resulting SQLite database. 

### Pipeline design and features 

The process file (process.md) describes the overall design of the pipeline, 
lists the necessary inputs and a high-level description of the steps in the 
workflow. 

The flowchart shows how user input and data move through the different 
pipeline functions. 

The pipeline
* creates a SQLite connection and database
* reads ONS and bridge files, merges them and adds them to the database 
* reads HES raw data files in chunks and adds it to the databasea after 
    + checking if all expected columns are present
    + coercing data types (optional)
    + cleaning variables 
    + deriveing variables (based on a single row of data)
    + combining with public data on deprivation and CCGs (optional)
    + flags comorbidities (to be made optional)
* flags duplicates in the database (optional)
* creates inpatient spells (not yet implemented)
* creates continuous inpatient spells (not yet implemented)
* creates summary tables for the clean dataset 

### Architecture design record (ADR)

The architecture design record (ADR) captures architectural decision and design 
choices, along with their context, rationale and consequences. 

So far, we have recorded decisions regarding
* where and how the raw data is stored and, if necessary, updated 
(data_location.md and data_storage_and_access.md)
* how the data is read in in chunks and how to determine the number of required
chunks per file (chunking_large_data_file_optimisation.md)
* how dates will be stored in the SQLite database (storing_dates_in_database.md)
* the chosen method to compare A&E arrivel time of two records while
identify duplicate records (comparing_arrivaltime_across_days.md)
* hardcoding variable names during cleaning and deriving steps (to be added)
* the methodology used to create inpatient spells (to be added)
* the methodology used to create continuous inpatient spells (to be added)


### Derived variables 

Derived variables are documented in [derived variables](doc/derived_variables.md)

## How does it work?

As the data prepared in this pipeline is not publicly available, the code 
cannot be used to replicate the database. However, with modifications the code 
will be able to be used on other patient-level HES extracts to prepare the 
datasets for analysis. For more information on how the pipeline works please 
refer to the [process document](doc/process.md).

## Requirements

The HES pipeline was built under R version 3.6.2 (2019-12-12) -- "Dark and Stormy Night".

The following R packages are required to run the HES pipeline:
*  data.table (1.12.2)
*  DBI (1.0.0)
*  dplyr (0.8.3)
*  furrr (0.1.0)
*  logger (0.1)
*  plyr (1.8.4)
*  rlang (0.4.0)
*  testthat (2.2.1)
*  tidylog (0.2.0)
*  tidyverse (1.2.1)
*  comorbidity (0.5.3)

## Installation

Download the HES Pipeline by either downloading or 
[cloning the repo](https://github.com/HFAnalyticsLab/HES_pipeline.git).

## Usage: running the pipeline to prepare HES for analysis

The pipeline can by run in two modes:
1. Building a HES database from scratch. This is the default. 
2. Update mode (`update = TRUE`). This incorporates data updates into an existing HES database. 


The following is needed to run the pipeline:
* **HES data extract** The pipeline can process any of the following patient-level
datasets: HES Admitted Patient Care, HES Accidents & Emergencies, HES Ouptatient
care, HES Critical Care and ONS Mortality records (including the bridge file 
linking it to HES). It requires at least one of them. The raw data files have to 
be located in the same folder. The path will be provided as the `data_path` argument 
to the `pipeline()` function call. 
* **SQLite database location (storage)** This is where the SQLite database will be built. 
This location will need to have sufficient storage space available to accomodate the
SQLite database, roughly equivalent to the combined file size of the raw HES data extract
plus 2 x file size of the A&E data set (as the tables for inpatient spells and
continuous inpatient spells will be added). The path to the folder will be provided as 
the `database_path` argument to the `pipeline()` function call. 
* **Dataset codes** The `data_set_codes` argument tells the pipeline which data 
sets to expect to find in the `data_path` folder. The codes only be all or a 
subset of "APC", "AE", "CC" and "OP", which also need to be present in the names of the 
raw files (in our experience, this is the case for raw HES files received directly 
from NHS Digital). ONS Mortality records are processed automatically if present
in the `data_path` folder. The file names for mortality records and bridge files 
should contain "ONS" and "BF", respectively.
* **Optional: chunk sizes** Each data file is read and processed in chunks, ie defnied a 
number of rows at a time. The default chunk size is 1 million lines but can 
also be set by the user. Larger chunk sizes (ie a lower number of chunks per file)
decrease the overall processing time significanctly. We think that this is because 
for each chunk in a given file, `fread()` needs progressively longer to move to 
the right row number to start reading data. As each dataset can have a different 
number of variables, and therefore requires different amounts of memory per row, 
chunk sizes have to be defined for each dataset separately. It is recommended to 
test this on a smaller subset of the data first, as very large chunk sizes can 
lead RStudio to crash. 
* **Expected column names** The pipeline requires a csv file listing the expected
column names for each data set. This table is expected to have at least two
column, `colnames` and `dataset`, similar to [csv]. Column headers are automatically 
capitalised while the data is read in, so the column names in the csv file should
be capitalised as well. This information will be used to check whether each raw
data file contains all expected columns. 
* **Optional: expected data types** By default, the function used to read in the 
data will automatically detect column types. The pipeline providesoption to coere 
each variables into user-defined types by setting the `coerce` argument to `TRUE`.
This required a third column `type` in the csv file mentioned above, see to [csv].
Note that since SQLite does not have a date datatype. Date variables need to be 
stored as integers. They should therefore be be listed as integers in the csv file. 
* **Optional: merging reference data** Additional reference data that can be merged 
in on the record level currenlty include Index of Multiple Deprivation (IMD), 2015
and/or 2019 versions, and CCG identifiers. The files paths to the reference files 
should be supplied as `IMD_2014_csv`, `IMD_2019_csv` and `CCG_XLSX` arguments and
will be joined on patient LSOA11. The data files can be downloaded from [to be added].
* **Optional: flagging duplicate records** This can be switched on by setting
`duplicate = TRUE`. Warning: this will significantly increase the run time of the pipeline.



Currently the pipeline is designed to run in an RStudio session. From the R
console compile the code:

`> source("pipeline.R")`

Then call `pipeline()`, providing as arguments a path to the data directory, a 
path to a directory for an SQLite database, a vector of dataset codes, a path 
to a csv with expected columns, inlcuding dataset codes and data types, an 
optional vector of the number of rows to be read at a time per datasets, and,
if required,and a boolean to enable coercion. The data will be processed and 
written to the database. N.B. This is a slow process and takes up a fair amount 
of memory to run.

Example run:

`> pipeline(data_path = "/home/user/raw-data/", 
            database_path = "/home/user/database-dir/", 
            data_set_codes = c("APC", "AE", "CC", "OP"), 
            chunk_sizes = c(2000000, 5000000, 2000000, 3000000), 
            expected_headers_file = "/home/user/expected_columns.csv", 
            IMD_15_csv = "IMD_2015_LSOA.csv", 
            IMD_19_csv = "IMD_2019_LSOA.csv", 
            CCG_xlsx = "xchanges-to-ccg-dco-stp-mappings-over-time.xlsx", 
            coerce = TRUE, update = FALSE, duplicate = FALSE)`

## Querying the clean HES data


```R
library(tidyverse)
library(dbplyr)
library (DBI)

con <- dbConnect(RSQLite::SQLite(), paste0(database_path, "HES_db.sqlite"))

# List available tables
dbListTables(con)

# List available variables in the A&E table
dbListFields(con, "AE")

# Option 1: Query using dbplyr
# Select table
AE <- tbl(con, 'AE')

# Look at the first 5 rows
AE %>% 
  head() %>% 
  collect()

# Option 2: Query using SQL
dbGetQuery(con,'SELECT * FROM AE LIMIT 5')

dbDisconnect(con)
```

What NOT to do (to be added).

## License

This project is licensed under the [MIT License](https://github.com/HFAnalyticsLab/HES_pipeline/blob/master/LICENSE).
