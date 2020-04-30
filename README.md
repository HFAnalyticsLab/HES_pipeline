# HES pipeline

Open-source R pipeline to clean and process patient-level Hospital Episode 
Statistics (HES) and linked ONS mortality data, with the aim to produce 
analysis-ready datasets for a defined programme of analyses.

#### Project Status: in progress

## Project Description

[Hospital Episode Statistics (HES)](https://digital.nhs.uk/data-and-information/data-tools-and-services/data-services/hospital-episode-statistics) is a database containing 
details of all hosptial admissions, A&E attendances and outpatient appointments 
at NHS hospitals in England.

Before it can be used for analysis, HES data requires cleaning, quality control and processing to derive additional variables. The complex record structure of HES, the large number of variables and the size of the data sets makes this a challenging task both from an analytical and computational point of view.

The semi-automated workflow we are developing in this repository processes HES data consistently and reproducibly, that all processing steps are documented, designed to ensure that each approved analysis projects is based on the same clean data.

## Data Source

We using HES data linked to ONS mortality data from 2008/09 up to the most recent quarterly 
release. Our data application has been approved by the NHS Digital [Data Access Request 
Service [Data Access Request Service (DARS)](https://digital.nhs.uk/services/data-access-request-service-dars).

The data will be accessed in The Health Foundation's Secure Data Environment; a 
secure data analysis facility (accredited with the ISO27001 information security
standard, and recognised for the NHS Digital Data Security and Protection
Toolkit). No information that could directly identify a patient or other 
individual will be used.

## Documentation

The doc folder contains information on: 
* HES data cleaning and processing protocol [to be added]
* [Logs](doc/logging.md) that are created during the run
* Definitions of [derived variables](doc/derived_variables.md)
* Definitions of [derived tables](doc/derived_tables.md)

In addition, sections below describe
* [pipeline design choices](https://github.com/HFAnalyticsLab/HES_pipeline#pipeline-design-and-features)
* how to [run the pipeline to prepare a HES extract for analysis](https://github.com/HFAnalyticsLab/HES_pipeline#pipeline-design-and-features)
* how to [query the resulting SQLite database](https://github.com/HFAnalyticsLab/HES_pipeline#querying-the-hes-database)
* [what to avoid when querying the database](https://github.com/HFAnalyticsLab/HES_pipeline#what-not-to-do)

## How does it work?

As the HES data prepared in this pipeline is not publicly available, the code 
cannot be used to replicate the same clean data and database. However, the code 
can be used on similar patient-level HES extracts to prepare the 
datasets for analysis. For more detailed information on how the pipeline works see below or 
refer to the [process document](doc/process.md).

### Pipeline design and features 

The [process document](doc/process.md) describes the overall design of the pipeline, 
lists the necessary inputs and a high-level description of the steps in the 
workflow. 

The flowchart shows how user input and data move through the different 
pipeline functions. 

The pipeline can by run in two modes:
1. **BUILD mode** creates a new HES database from scratch (this is the default). 
2. **UPDATE mode** incorporates data updates into an existing HES database (if `update = TRUE`). HES data updates within the same year are overlapping, so some of the old data will be dropped and replaced with the new update. ONS mortality data is completely refreshed with each data update.  

In **BUILD mode**, the pipeline
* creates a SQLite database
* reads ONS mortality and HES bridge files, merges them and adds them as a new table to the database 
* per HES dataset, reads HES raw data files in chunks and adds it to the respective table in the database after 
    + checking if all expected columns are present
    + coercing data types (optional)
    + cleaning variables 
    + deriving new variables (for variables based on individual records or rows)
    + combining with public data on LSOA-level Index of multiple deprivation and CCGs (optional)
    + flagging comorbidities and calculating the Charlson, Elixhause and a custom frailty index (optional)
* flags duplicates in the database (optional)
* creates inpatient spells 
* creates continuous inpatient spells 
* creates summary tables for the clean dataset and saves them to the database and as csv files. 

In **UPDATE mode**, the pipeline
* detects which data year to update from the file name of the raw files to be processed
* deletes the subset of records that will be replaced for each HES dataset as well as the ONS table
* moves the existing data into temporary backup tables
* processes the new data (as above, up to the duplicate flagging step)
* joins the existing records with the new data update
* creates inpatient spells on the combined data
* creates continuous inpatient spells on the combined data
* creates summary tables for the clean dataset and saves them to the database and as csv files. 

### Architecture/analysis decision record

The architecture decision record (ADR) captures architectural decision and design 
choices, along with their context, rationale and consequences. In addition, we recorded some
analytical decisions.

So far, we have recorded decisions regarding
* [where](doc/adr/data_location.md) and [how](doc/adr/data_storage_and_access.md) the raw data is stored and, if necessary, updated
* how the data is [read in in chunks](doc/adr/chunking_large_data_file_optimisation.md) and how to determine the number of required chunks per file 
* how dates will be [stored in the SQLite database](doc/adr/storing_dates_in_database.md)
* the chosen method to [compare A&E arrival time of two records](doc/adr/comparing_arrivaltime_across_days.md) while
identify duplicate records 
* how admission date will be [imputed if missing](doc/adr/imputing_admission_date.md)
* [hardcodeding of some column names](doc/adr/hardcoding_variables.md)
* the methodology used to create [inpatient spells](doc/adr/creating_inpatient_spells.md) 
* the methodology used to create [continuous inpatient spells](doc/adr/creating_continuous_inpatient_spells.md) 
* the definition of the [custom frailty index](doc/adr/frailty_score.md) calculated using admitted patient care data. 

## Requirements

### Software and R packages

The HES pipeline was built under R version 3.6.2 (2019-12-12) -- "Dark and Stormy Night".

The following R packages, which are available on CRAN, are required to run the HES pipeline:
*  [data.table](https://cran.r-project.org/web/packages/data.table/index.html) (1.12.2)
*  [DBI](https://cran.r-project.org/web/packages/DBI/index.html)(1.0.0)
*  [tidyverse](https://www.tidyverse.org/)(1.2.1)
*  [tidylog](https://cran.r-project.org/web/packages/tidylog/index.html)(0.2.0)
*  [readxl](https://cran.r-project.org/web/packages/readxl/index.html)(1.3.3)
*  [furrr](https://cran.r-project.org/web/packages/furrr/index.html) (0.1.0)
*  [logger](https://cran.r-project.org/web/packages/logger/index.html) (0.1)
*  [plyr](https://cran.r-project.org/web/packages/plyr/index.html) (1.8.4)
*  [rlang](https://cran.r-project.org/web/packages/rlang/index.html) (0.4.0)
*  [comorbidity](https://cran.r-project.org/web/packages/comorbidity/index.html) (0.5.3)

### Storage capacity

The location where the database is created needs to have sufficient storage space available, roughly equivalent to the combined file size of the raw HES data extract plus 2 x file size of the APC data set (as the tables for inpatient spells and continuous inpatient spells will be added).

### Temporary storage

Some of the processing steps are not performed in memory but as SQLite queries. This includes the duplicate flagging algorithm, spell creation and the creationg of summary statistics tables on the clean data. Depending on the size of the dataset, these steps create large temporary SQLite databases (.etiqls files), which are automatically deleted once the query has been executed. By default, these are created in the R home directory, which is often located on a drive with restricted storage capacity. 

We have found that execution of the pieline fails when not enough temporary storage is available (error message 'Database or disk is full'). This can be fixed by changing the location where temporary SQLite databases are created. On Windows, the temporary storage location is controlled by the environmental variable "TMP". We recommended to create a project-level .Renviron file to set TMP to a location with sufficient storage capacity. 

## Running the pipeline 

### Required arguments

* `data_path` Path to the HES data extract.     
The pipeline can process any of the following patient-level
datasets: HES Admitted Patient Care, HES Accidents & Emergencies, HES Ouptatient
care, HES Critical Care and ONS Mortality records (including the bridge file 
linking it to HES). It requires at least one of them. The raw data files have to 
be located in the same folder. 

* `database_path` Path to a folder where the SQLite database will be built. 

*  `data_set_codes` Expected HES datasets in the `data_path` folder.     
This should be one or several of "APC", "AE", "CC" and "OP". These identifiers are matched to the names of the raw files, which should be the case for raw HES files received from NHS Digital. ONS Mortality records and ONS-HES bridge files are processed by default if present. The file names for mortality records and bridge files should contain "ONS" and "BF", respectively.

* `expected_headers_file` Path to a csv file with expected column names for each data set.    
This csv file has at least two columns, named `colnames` and `dataset`, similar to [this template](doc/HES_expected_columns.csv). Column headers in the data are automatically capitalised while the data is read in, so the column names in the csv file should be all caps. This information will be used to check whether each raw
data file contains all expected columns. 

### Optional arguments 

The following arguments have a default setting:

* `chunk_sizes` Number of rows per chunk for each data set.    
Each data file is read and processed in chunks of defied a number of rows. The default size is 1 million lines per chunk but this can be modified by the user. Larger chunk sizes, resulting in a smaller number of chunks per file, decrease the overall processing time. This is probably because for each chunk in a given file, `fread()` needs progressively longer to move to the specified row number to start reading the data. However, large chunk sizes also increase the time in takes to process each chunk in memory. The optimal chunk size balances processing time with reading time and is dependent on the system and the dataset, as each dataset can have a different number of variables, and therefore requires different amounts of memory per row. It is recommended to run tests on a smaller subset of data first, as very large chunk sizes can 
cause RStudio to crash. 

* `coerce` Coercing data types.    
By default, the `fread()` function used to read in the data will automatically detect column types.    
Alternatively, data types can be coerced to user-defined types by setting this argument to `TRUE`.
Column types are supplied int the third column, called `type`,  in the csv file with the expected 
column names, see [this template](doc/HES_expected_columns.csv). Note that SQLite does not have a date datatype. Date variables need to be stored as characters and should therefore be be listed as characters in the csv file. 

* `IMD_2014_csv`, `IMD_2019_csv` and `CCG_xlsx` Paths to files containing reference data to be merged.   
Additional reference data that can be merged to each record currentlyy include the Index of Multiple Deprivation (IMD), 2015 and/or 2019 versions, and CCG identifiers. The files paths to the reference files 
should be supplied as  arguments and will be joined on patient LSOA11. The csv files containing LSOA11-to-IMD mappings need to have a column name that starts with "LSOA code", a column name that contains "Index of Multiple Deprivation (IMD) Rank" and a column name that contains "Index of Multiple Deprivation (IMD) Decile". The lookup files for [IMD 2015](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2015) and [IMD 2019](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2019) can be downloaded from GOV.UK (File 7:  all ranks, deciles and scores for the indices of deprivation, and population denominators). The lookup file for [CCG identifiers](https://www.england.nhs.uk/publication/technical-guide-to-ccg-allocations-2018-19-apr-2018-spreadsheet-files-for-ccg-allocations-2018-19/) can be downloaded from NHS Digital (File: X - Changes to CCG-DCO-STP mappings over time). 

* `update` Switch pipeline mode.     
Pipeline mode is switched from BUILD to UPDATE mode by setting this argument to `TRUE`.

* `duplicate` Flagging duplicate records.   
Additional columns will be created in the APC, A&E and OP dataset that indicitates whether or not a record is likely to be a duplicate if this argumet is set to `TRUE`. The definition and derivation rules can be found in (derived_variables.md). Warning: this will significantly increase the run time of the pipeline.

* `comorbiditees` Flagging comorbidities.    
Additional columns will be created in the APC dataset, including flags for individual conditions and weighted and unweighted Charlson and Elixhauser scores if this argument is set to `TRUE` (also see the documentaion of the R package comorbidity). In addition, the pipeline flags conditions related to frailty and calculates a custom frailty index (see ?).Warning: this will significantly increase the run time of the pipeline.


### Usage

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
            coerce = TRUE, update = FALSE, duplicates = FALSE, comorbidities = FALSE)`

## Querying the HES database

For guides on how to query SQLite databases from R, for example see the RStudio tutorial [Databases using R](https://db.rstudio.com/).

The database can be queried:
1. By writing SQLite syntax and executing these queries in R using the DBI package
2. By writing R dpyr syntax and using the SQL backend provided by dbplyr to translate this code into SQLite. 
3. more to be added. 

### Example queries using DBI and dbplyr

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

## What to avoid when querying the database

If you are using DBI, use the `dbGetQuery()` function. Avoid using functions that could modify the underlying database, such as `dbExecute()`, `dbSendQuery()` or `dbSendStatement()`. 

## Authors
* **Fiona Grimm** - [@fiona_grimm](https://twitter.com/fiona_grimm) - [fiona-grimm](https://github.com/fiona-grimm)
* **Sebastian Bailey** - [@sseb231](https://twitter.com/sseb231) - [seb231](https://github.com/seb231)

## License

This project is licensed under the [MIT License](https://github.com/HFAnalyticsLab/HES_pipeline/blob/master/LICENSE).
