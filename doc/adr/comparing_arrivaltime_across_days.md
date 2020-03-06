# Comparing ARRIVALTIME across days

## Context

When identifying duplicates in the AE dataset a one of the columns to test 
for equality between rows is ARRIVALDATE. If this is identical, a difference 
in ARRIVALTIME of <1hr between rows is then used as an indicator of a 
duplicate row. This means when there are two rows with arrival times between 
2330 and 0030, these will not be identified as duplicates as these rows have 
not passed the test for equality on ARRIVALDATE.


## Decision

We anticipate a very low number of rows matching this issue and have chosen to
not further complicate the duplication identification process.

## Status

Implemented.

## Consequences

Where two rows with arrival times between 2330 and 0030, and all other selected 
rows are identical, these rows will not be identified as duplicates as they have 
not passed th prior test for equality on ARRIVALDATE.