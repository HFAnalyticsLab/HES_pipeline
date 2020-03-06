# Logging

The pipeline writes two logs as .txt files to the same location as the SQLite 
database (`database_path`):

## **pipeline log**

This log captures: 
* the overall progression of the pipeline run (time stamps)
* the latest git commit to keep track of versioning
* the file names and locations of each raw file that is being processes
* whether or not each raw file contained expected column headers
* the time taken to read and process each chunk, as well as the number of lines
per chunk
* the time taken to read and process each file and dataset
* any errors that cause the pipeline to fail.

## **tidy log**

For each chunk this log captures console feedback on most variable transformations, 
as provided by the **tidylog** package.

