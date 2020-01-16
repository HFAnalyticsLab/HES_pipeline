# Chunking large data file optimisation

## Context

In order to process the large HES data, optimisation of the reading in of flat
files and writing out to SQLite was required.

`fread` from the data.table R package, provides reading in of large datasets
with the option of chunking the data into smaller, more managable pieces. Chunks
are defined by row numbers. `fread` will take precise row numbers, or will throw
an exception if the row number it has been told to delimit by does not exist.

## Decision

Tests showed that reading in a chunk whereby the row number to read-in was 
outside the possible number of rows for a file, was slower to throw an 
exception, than first counting the number of rows, by selecting only a single 
column to read-in, and reading every row, and using that count to inform the 
loop function which iterates over the file to be read in.

As this data is being read-in we have chosen to make use of it, by selecting the
column to read in as the encrypted HES IDs. A unique list of these IDs will be 
compiled and will form an initial master patient index.

## Status

Implemented, with potential further future optimisation.

## Consequences

A file is read in an additional time in order to do a row count.

Some data files are small and do not require this row count and chunking, but 
are being treated equally.

A large vector is created and appended to, each time a new file is read in, 
adding to the processing time.
