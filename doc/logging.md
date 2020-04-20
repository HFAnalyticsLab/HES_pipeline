# Logging

The pipeline writes two logs as .txt files to the same location as the SQLite 
database (`database_path`):

## **pipeline log**

This log captures: 
* pipeline version (last git commit)
* whether the pipeline is run in build or update mode
* file names and locations of raw data files and reference data files
* optional arguments that were provided to the pipline function (data type coercion, duplicate flagging, comorbidity flagging)
* individual high-level processing steps with time stamps, including 
    + whether or not each raw file contained expected column headers
    + the time taken to read and process each chunk, as well as the number of lines
per chunk
    + the time taken to read and process each file and dataset
* any errors that cause the pipeline to fail.

## **tidy log**

This log captures detailed console feedback on most variable transformations, 
as provided by the **tidylog** package.

