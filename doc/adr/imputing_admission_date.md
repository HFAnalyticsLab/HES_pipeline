# Imputing admission date

## Context

Admission date (ADMIDATE in the APC dataset) can occasionally be missing, 
however it can be imputed from other variables.

## Decision

If ADMIDATE is missing but EPISTART is present (start of hosptial episode),
is the first episode (EPIORDER = 1) and is not a transfer (ADMIMETH not 67 or 
81 and ADMISORC not 51, 52 or 53), we accept that the date in EPISTART is also
the admission date. 

## Status

Implemented.

## Consequences

An additional variable (ADMIDATE_FILLED) is created to differentiate between 
raw admission date and imputed admission date. If EPISTART is also missing, 
ADMIDATE_FILLED cannot be imputed. 