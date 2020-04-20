# Storing dates in SQLite database

## Context

SQLite does not feature a date format data type. As such writing a date format
data object from R, results in conversion to an integer with no relevance to the
original date.

## Decision

Incoming raw data will not be converted to date format in R, and instead 
maintained as a string for full dates (Y-m-d) or part dates (Y-m) and as an 
integer for years.

## Status

Implemented, and previous code for date conversion has been rolled back.

## Consequences

For date analyses, when using the HES database date columns must be converted to
date format after performing a query. A handy function has been created to do 
this in a standardised way (see [here](src/clean.R#L28))