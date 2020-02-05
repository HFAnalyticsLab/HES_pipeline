# HES_pipeline

Open-source R pipeline to clean and process patient-level Hospital Episode 
Statistics (HES) & ONS Civil Registrations data, with the aim to produce 
analysis-ready datasets for a defined programme of analyses.

#### Project Status: Development

## Project Description

[Hospital Episode Statistics (HES)](link to be added) is a database containing 
details of all hosptial admissions, A&E attendances and outpatient appointments 
at NHS hospitals in England.

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
Service (DARS)](link to be added) and development of this pipeline has now 
commenced.

The data will be accessed in The Health Foundation's Secure Data Environment; a 
secure data analysis facility (accredited with the ISO27001 information security
standard, and recognised for the NHS Digital Data Security and Protection
Toolkit). No information that could directly identify a patient or other 
individual will be used.

## How does it work?

As the data prepared in this pipeline is not publically available, the code 
cannot be used to replicate the database. However, with modifications the code 
will be able to be used on other patient-level HES extracts to prepare the 
datasets for analysis. For more information on how the pipeline works please 
refer to the [process document](doc/process.md).

## Installation

Download the HES Pipeline by either 
[downloading](link to be added) 
or cloning the repo with 
[ssh](link to be added)
or [http](link to be added).

## Requirements

The HES pipeline was built under R version 3.5.1 (2018-07-02) -- "Feather 
Spray".

The following R packages are required to run the HES pipeline:
*  data.table (1.12.0)
*  tidyverse (1.2.1)
*  DBI (1.0.0)

## Usage

Currently the pipeline is designed to run in an RStudio session. From the R
console compile the code:

`> source("load_data.R")`

Then call `pipeline()` from pipeline.R, providing as arguments a path to the data directory, a 
path to a directory for an SQLite database, a vector of dataset codes and a path 
to a csv with expected columns, inlcuding dataset codes and data types, if required. The data 
will be processed and written to the database. N.B. This is a slow process and takes up a fair 
amount of memory to run.

Example run:

`> pipeline("/home/user/raw-data/". "/home/user/database-dir/", c("FOO", "BAR"),
"/home/user/expected_columns.csv")`

## License

This project is licensed under the [MIT License](LICENSE)