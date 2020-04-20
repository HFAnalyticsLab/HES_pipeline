# Defining an inpatient spell

### Context

A hospital spell is defined as a period of care with one hospital provider (trust), 
from admission to discharge or transfer. A spell can be made up of one or more 
Finished Consultant Episodes (FCE), which is a continuous period of care under one
consultant. Most spells consist of one episode or one row in the APC dataset 
but some spells contain multiple episodes. Each patient can have multiple 
episodes and/or multiple spells.

### Decision

An episode is considered "valid" for creating a spell when it is finished (EPISTAT 
equals 3) and the following are not missing:
* ENCRYPTED_HESID
* ADMIDATE_FILLED
* PROCODE3
* EPIKEY
* EPISTART
* EPIEND

All episodes within a spell have to have the same:
* ENCRYPTED_HESID
* PROCODE3

Within each group of ENCRYPTED_HESID and PROCODE3 combinations, rows are then 
ordered by:
* EPISTART
* EPIEND
* EPIORDER
* TRANSIT
* EPIKEY

An episode is considered to be part of the same spell as the previous episode
if *one of the following* is true:
* ADMIDATE_FILLED of the current episode is the same as for the previous episode
* EPISTART of the current episode is the same as for the previous episode
* The method of discharge of the previuos episode is a tranfer (DISMETH is 8 or 9) 
and the episode start date (EPISTART) of the current episode matches the episode 
end date of the previous episode (EPIEND)

There are two derived variables correspondong to spells information:
* NEW_SPELL - TRUE if the episode marks the beginning of a new spell, FALSE otherwise
* SPELL_ID - Spell identifier, unique in combination with ENCRYPTED_HESID

A new spell table (APCS) is then created, containing one row per spell (or per unique combination of ENCRYPED_HESID and SPELL_ID). This table is populated using 
* information derived from the **first episode** within in each
spell, **excluding** the following columns: EPIEND, DISDATE, DISDEST, DISMETH, DISREADYDATE, EPIKEY, EPIDUR, EPIORDER, EPISTAT, MAINSPEF, SPELBGIN, SPELDUR, SPELEND, TRETSPEF, CONSULT_TYPE, ENCRYPTED_HESID_MISSING,PROCODE3_MISSING, TRANSIT, ADMIDATE_MISSING, EPIDUR_CALC,
EPI_BAD, EPI_VALID, NEWSPELL, ROWCOUNT, SUBDATE, SUSCOREHRG, SUSHRG, SUSHRGVERS and SUSRECID.
* information derived from the **last episode** within each spell (where EPIORDER = MAX(EPIORDER)) only **including** the following column: DISDATE, DISDEST, DISMETH, DISREADYDATE, EPIKEY (renamed to EPIKEY_DIS) and EPIEND. NB if a spell only contains one episode, then the first and the last episode are the same. 

### Status

Implemented (see [spells.R](src/spells.R)).

### Consequences

NEW_SPELL and SPELL_ID are set to NA for episodes which are not valid.
