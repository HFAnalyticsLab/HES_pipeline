# Defining an inpatient spell

### Context

A continuous inpatient spell (CIPS) is defined as a sequence of inpatient spells with different hospital 
providers, from the patients admission to discharge to the usual place of 
residence. Spells are considered to be part of the same CIPS up to 
three days, equivalent to two nights, have passed between discharge from one provider and 
admission to another provider. Each patient can have multiple inpatient
spells and/or multiple continuous inpatient spells.
    

### Decision

All spells within a CIPS have to have the same:
* ENCRYPTED_HESID

Within each group of spells belonging to the same ENCRYPTED_HESID, rows are then 
ordered by ADMIDATE_FILLED.

A spell is considered to be part of the same CIPS as the previous spell if EPISTART is not more than
3 days later than EPIEND of the previous spell *and one of the following* is true:
* The discharge destination of the previous spell is another hospital (DISDEST is 51, 52 or 53)
* The source of admission of the current spell another hospital (ADMISORC is 51, 52 or 53)
* The method of admission of the current spell is a transfer (ADMIMETH is 2B, which recoded to 67 during cleaning, or 81)


There are two derived variables correspondong to CIPS information:
* NEW_CIPS - TRUE if the episode marks the beginning of a new CIPS, FALSE otherwise
* CIPS_ID - CIPS identifier, unique in combination with ENCRYPTED_HESID

A new CIPS table (APCC) is then created, containing one row per CIPS (or per unique combination of ENCRYPED_HESID and CIPS_ID). This table is populated using 
* information derived from the **first spell** within in each
CIPS, **excluding** the following columns: EPIEND, DISDATE, DISDEST, DISMETH, DISREADYDATE, EPIKEY,
EPIDUR, EPIORDER, EPISTAT, MAINSPEF, SPELBGIN, SPELDUR, SPELEND, TRETSPEF, CONSULT_TYPE, ENCRYPTED_HESID_MISSING,PROCODE3_MISSING, TRANSIT, ADMIDATE_MISSING, EPIDUR_CALC, EPI_BAD, EPI_VALID, NEWSPELL, ROWCOUNT, PROCODE3, SUBDATE, SUSCOREHRG, SUSHRG, SUSHRGVERS, SUSRECID.
* information derived from the **last spell** within each CIPS (where EPIORDER = MAX(EPIORDER)) only **including** the following column: DISDATE, DISDEST, DISMETH, DISREADYDATE, PROCODE (renamed to PROCODE3_LAST_CIPS) and EPIEND. NB if a CIPS only contains one spell, then the first and the last episode are the spell. 


### Status

Implemented (see [spells.R](src/spells.R)).

### Consequences
