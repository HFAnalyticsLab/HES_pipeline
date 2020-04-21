The HES pipeline tool has four requires user parameters: 
* a path to a directory where the
data is stored, 
* a path to a location where an SQLite database can be created or is 
located, 
* a vector of dataset codes, 
* the path to a CSV of expected columns     
as well as 8 optional parameters (see [Running the pipeline](https://github.com/HFAnalyticsLab/HES_pipeline#running-the-pipeline) for more information).


### BUILD mode
1. Using the data directory path, recover all filenames therein.
2. Create a SQLite connection and database at the database path.
3. Create log files.
4. Load external reference data. 
5. Load a csv of expteced column names, dataset label and data type 
([for example](tests/dummy_data/example_expected.csv)).
6. Using the data directory path, recover all filenames therein.
7. Using a set list of dataset codes, the filenames are partitioned into their 
respective datasets.
8. If ONS datasets present:
    1. Read in the data, coercing data types
    2. Confirm all headers are present
    3. Merge ONS and bridge data (required to combine ONS with HES data)
    4. Parse data
    5. Derive new variables
    6. Write the data to a table in the SQLite database
    7. Log table name and processing time
9. Iterate over each HES dataset:
    1. Iterate over each file in a dataset:
        1. Read in the ID column for the file
        2. Count the number of rows
        3. Divide the row count into 1 million row chunks
        4. Store the first row as the header for the database table
        5. For each 1 million row chunk in a file:
            1. Read in the data, coercing data types
            2. Confirm all headers are present
            3. Parse data
            4. Derive new variables
            5. Write the data to a table in the SQLite database
            6. Log file name, number of records and processing time
    2. Log dataset name, total number of records and total processing time
10. Update database
    1. If switched on, flag duplicates in APC, AE and OP datasets
    2. If present, update derived variables in AE dataset
11. Create inpatient spells and continuous inpatient spells
12. Create summary tables, save as csv and add to database
13. Close SQLite connection.

The following diagram describes this process as a flowchart. Functions are 
marked as green squares, user parameters to be input to the pipeline are gold
parallelograms and data structures are white parallelograms. A data structure
with no exit workflow is also an output. The workflow is indicated by the 
direction of the blue arrows, while the looping section is demarked by the 
hashed red line. 

![flowchart](https://github.com/HFAnalyticsLab/HES_pipeline/blob/master/doc/flowchart.png)

### UPDATE mode

1. Create a SQLite connection to the existing database at the database path.
2. Create log files.
3. Using the data directory path, recover all filenames therein.
4. Using a set list of dataset codes, the filenames are partitioned into their 
respective datasets.
5. Using the file names for HES data, determine which records to replace with the partially overlapping HES data update. 
6. Load external reference data. 
7. Remove records from the database. 
8. Move remaining records to a backup location.
9. Load a csv of expteced column names, dataset label and data type 
([for example](tests/dummy_data/example_expected.csv)).
10. If ONS datasets present:
    1. Read in the data, coercing data types
    2. Confirm all headers are present
    3. Merge ONS and bridge data (required to combine ONS with HES data)
    4. Parse data
    5. Derive new variables
    6. Write the data to a table in the SQLite database
    7. Log table name and processing time
11. Iterate over each HES dataset:
    1. Iterate over each file in a dataset:
        1. Read in the ID column for the file
        2. Count the number of rows
        3. Divide the row count into 1 million row chunks
        4. Store the first row as the header for the database table
        5. For each 1 million row chunk in a file:
            1. Read in the data, coercing data types
            2. Confirm all headers are present
            3. Parse data
            4. Derive new variables
            5. Write the data to a table in the SQLite database
            6. Log file name, number of records and processing time
    2. Log dataset name, total number of records and total processing time
12. Update database
    1. If switched on, flag duplicates in APC, AE and OP datasets
    2. If present, update derived variables in AE dataset
13. Merge existing records with newly processed records. 
14. Create inpatient spells and continuous inpatient spells
15. Create summary tables, save as csv and add to database
10. Close SQLite connection.


![flowchart](https://github.com/HFAnalyticsLab/HES_pipeline/blob/master/doc/update_db_flowchart.PNG)
