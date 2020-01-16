# Where is the data stored and updated

## Context

Incoming data from NHS is not handled by users of the HES pipeline. This makes 
it harder to control the directory format of the raw data, as well as the 
consistency of that data and directory structure.

Additionally the SQLite database needs to be located in a writable environment.

## Decision

The raw data will be copied manually from the Data directory to the Library
directory. Subsequent updates to the raw data will also require this. This is 
also where the database will be located and written to.

## Status

Decided.

## Consequences

The raw data will exist in three locations, using additional space.

A manual step of copying over the new data is required, but can be handled by
the same person who will then run the pipeline to process the new data in the 
database.