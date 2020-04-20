# Hardcoding variable names

## Context

Several parts of the pipeline execute operations on specific columns. 

## Decision

Where there was an easy way to do so, we gave users the options to supply variable names:
* checking whether all expected columns are present
* coercing data types.

In other sections of the pipeline, variable names had to be hardcoded:
* cleaning variables (replacing missing values with NA)
* deriving variables
* deriving row quality and flagging duplicates (optional)

## Status

Implemented, with potential further future optimisation.

## Consequences

Column names currently cannot be dynamically supplied by the user. Adapting the HES pipeline to other HES extracts might require modification of some functions. We expect this only to be an issue if a HES extract has additional variables that need to be processed. If any of the expected variables are not present in a HES 
extract, the pipeline will continue without error. 
