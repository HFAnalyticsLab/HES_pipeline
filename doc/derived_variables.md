# Documentation for derived variables
   
The variables listed here are derived during the `build_database` stage and during
the `update_database` stage of the pipeline. They are created only if their 
dependencies are present in the data table. 
    
## Documentation template
VARIABLE_NAME   
**Label:**  
**Description:**    
**Table:** AE, APC, CC, OP, ONS    
**Data type:**     
**Values:**     
**Missing values**:    
**Derivation function:** R function used to derive the variable    
**Derivation rules:**  
**Dependencies:** creation of derived variables depends on the variables listed 
here   
**Usage:**
**References:** 
    
Abbreviations for raw data tables:    
**AE** - HES Accidents & Emergencies    
**APC** - HES Admitted Patient Care    
**CC** - HES Critical Care    
**OP** - HES Outpatients    
**ONS** - ONS Mortality Records (+ HES bridge file)    

Abbreviations for derived data tables:    
**APCS** - HES Admitted Patient Care Inpatient Spells    
**APCC** - HES Admitted Patient Care Continuous Inpatient Spells    


## ADMIDATE_FILLED    
**Label:** Date of admission    
**Description:** More complete version of the date the patient was admitted
to hospital at the start of a hospital spell.       
**Table:** APC    
**Data type:** character (see adr/storing_dates_in_database.md)    
**Values:**     
**Missing values**: `NA`    
**Derivation function:** `derive_admidate_filled()`     
**Derivation rules:**  If date of admission is missing but episode start date is
present, episode order is 1, the method of admission is not a transfer and the 
source of admission is not a hospital ward, then complete the admission date using
the episode start date.   
**Dependencies:** ADMIDATE, ADMIMETH, ADMISORC, EPIORDER, EPISTART      
**Usage:** Used to create inpatient spells.    
**References:** [Imputing admission date](doc/adr/imputing_admission_date.md)

## ADMIDATE_MISSING    
**Label:**  Date of admission missing    
**Description:** Flag indicating whether encrypted HES-ID is missing or not.    
**Table:** APC 
**Data type:** logical        
**Values:** TRUE/1 = yes, FALSE/0 = no    
**Missing values**:     
**Derivation function:** `derive_missing()`     
**Derivation rules:**  `ifelse(is.na(ADMIDATE), TRUE, FALSE)`    
**Dependencies:** ADMIDATE_FILLED  
**Usage:** Used to exclude episode with missing admission date when creating 
inpatient spells.    
**References:**

## APPTDATE_MISSING    
**Label:** Appointment date missing    
**Description:** Flag indicating whether the date when the appointment was scheduled
is missing or not.    
**Table:** OP    
**Data type:** logical        
**Values:** TRUE/1 = yes, FALSE/0 = no         
**Missing values**:     
**Derivation function:** `derive_missing()`    
**Derivation rules:**  `ifelse(is.na(APPTDATE), TRUE, FALSE)`    
**Dependencies:** APPTDATE    
**References:**

## ARRIVALDATE_MISSING
**Label:** Arrival date missing    
**Description:** Flag indicating whether arrival date of a patient in the A&E 
department is missing or not.    
**Table:** AE    
**Data type:** logical           
**Values:** TRUE/1 = yes, FALSE/0 = no     
**Missing values**:     
**Derivation function:** `derive_missing()`    
**Derivation rules:**  `ifelse(is.na(ARRIVALDATE), TRUE, FALSE)`    
**Dependencies:** ARRIVALDATE    
**References:**  

## CCG_x
**Label:** CCG Identifiers    
**Description:** 11 columns with CCG identifiers for each generation from 2013 to 2019. Created using publicly available reference files by merging on LSOA11.       
**Table:** AE, APC, OP           
**Data type:** character    
**Values:**      
**Missing values**: `NA`     
**Derivation function:** `read_write_HES()`    
**Derivation rules:**  
**Dependencies:** LSOA11    
**References:*

## CHARLSON_x
**Label:** Charlson comorbidity score    
**Description:** 21 columns in total, including
* 17 columns are flags for individual conditions that form the Charlson score: CHARLSON_AMI (acute myocardial infarction), CHARLSON_CHF
(congestive heart failure), CHARLSON_PVD 9congestive heart failure), CHARLSON_CEVD (cerebrovascular disease), CHARLSON_DEMENTIA (dementia), CHARLSON_COPD (chronic obstructive pulmonary disease), CHARLSON_RHEUMD (rheumatoid disease), CHARLSON_PUD (peptic ulcer disease), CHARLSON_MLD (mild liver disease), CHARLSON_DIAB (diabetes without complications), CHARLSON_DIABWC (diabetes without complications), CHARLSON_HP (hemiplegia or paraplegia), CHARLSON_REND (renal disease), CHARLSON_CANC (cancer, any malignancy), CHARLSON_MSLD (moderate or severe liver disease), CHARLSON_METACANC 
(metastatic solid tumour), CHARLSON_AIDS (AIDS/HIV)
* CHARLSON_SCORE (non-weighted version of the Charlson score)
* CHARLSON_INDEX (non-weighted version of the grouped Charlson index)
* CHARLSON_WSCORE (weighted version of the Charlson score)
* CHARLSON_WINDEX (weighted version of the grouped Charlson index)    
**Table:** APC        
**Data type:**     
**Values:**     
**Missing values**:     
**Derivation function:** `derive_comorbidities()`    
**Derivation rules:** Only derived if `comorbidities= TRUE`.    
**Dependencies:** all columns matching the pattern "DIAG_"    
**References:** also see the [documentation of the R package comorbidity](https://cran.r-project.org/web/packages/comorbidity/vignettes/comorbidityscores.html)     


## CIPS_ID
**Label:** Continuous inpatient spell identifier    
**Description:** An identifier for each continuous inpatient spell (CIPS), 
which is unique in combination with ENCRYPTED_HESID. A continuous inpatient 
spell is defined as a sequence of inpatient spells with different hospital 
providers, from the patients admission to discharge to the usual place of 
residence. Spells are counted as being part of the same CIPS if there are up to 
three days, equivalent to two nights, between discharge from one provider and 
admission to another provider.    
**Table:** APCS        
**Data type:** integer    
**Values:**     
**Missing values**:     
**Derivation function:** `derive_cips_id()`    
**Derivation rules:** CIPS_ID is set to 1 for spells belonging to the first 
inpatient spell of each patient, and increased by one for spells belonging to 
subsequent spells.   
**Dependencies:** ADMIMETH, AMISORC, ENCRYPTED_HESID, EPIEND, EPISTART, DISDEST, 
NEW_CIPS    
**References:** [Creating continuous inpatient spells](doc/adr/creating_continuous_inpatient_spells.md)    

    
## DISDATE_MISSING
**Label:** Date of discharge missing  
**Description:** Flag indicating whether the date the patient was discharged 
from hospital at the end of an inpatient spell is missing.   
**Table:** APCS    
**Data type:** logical           
**Values:** TRUE/1 = yes, FALSE/0 = no     
**Missing values**:     
**Derivation function:** `derive_disdate_missing()`    
**Derivation rules:** 
**Dependencies:** DISDATE     
**References:**

## DOD_FILLED    
**Label:** Date of death    
**Description:** More complete version of the date on which the patient died.     
**Table:** ONS    
**Data type:** character (see adr/storing_dates_in_database.md)      
**Values:**     
**Missing values**: `NA`     
**Derivation function:** `derive_dod_filled()`    
**Derivation rules:** If date of death is missing but date of registration is present,
repace date of death with date of registration.    
**Dependencies:** DOD, DOR     
**References:**    

## DUPLICATE
**Label:** Duplicate record  
**Description:** Flag indicating whether a record is a duplicate or not.   
**Table:** AE, APC, OP      
**Data type:** logical    
**Values:** TRUE/1 = yes, FALSE/0 = no      
**Missing values**:     
**Derivation function:** `flag_duplicates()`    
**Derivation rules:** Only derived if `duplicates = TRUE`.   
**[AE]** If two rows have the same encrypted HES-ID, arrival date, provider code
(3 character), primary diagnosis and first treatment and the arrival time is within
60 minutes, then flag the less complete row as a duplicate. If the row
quality is the same, then flag the row with the older submission date. If the 
submission date is the same, flag the first row.
**[APC]** If two rows have the same encrypted HES-ID, episode start, episode end,
episode order, provider code (3 character), transit variable, admission date, 
and discharge date, then flag the less complete row as a duplicate. If the row
quality is the same, then flag the row with the older submission date. If the 
submission date is the same, then flag the row with the lower record identifier.
If the 
submission date is the same, flag the first row.
**[OP]** If two rows have the same encrypted HES-ID, appointment date, provider 
code (3 character), main specialty, treatment specialty, then flag the less 
complete row as a duplicate. If the row quality is the same, then flag the row 
with the older submission date. If the 
submission date is the same, flag the first row.    
**Dependencies:**    
**[AE]** ENCRYPTED_HESID, ARRIVALDATE, ARRIVALTIME, DIAG_01, ROWQUALITY, PROCODE3, 
TREAT_01    
**[APC]** ADMIDATE_FILLED, DISDATE, ENCRYPTED_HESID, EPIEND, EPIKEY, EPIORDER, EPISTART, 
PROCODE3, ROWQUALITY, SUBDATE, TRANSIT    
**[OP]** ATTENDED, ENCRYPTED_HESID, APPTDATE, MAINSPEF, ROWQUALITY, PROCODE3, TRETSPEF   
**Usage:** Used to exclude duplicate records when determining which A&E attendances
were unplanned and which were seen (SEEN, UNPLANNED, UNPLANNED_SEEN).    
**References:**      

## ENCRYPTED_HESID_MISSING    
**Label:**  Encrypted HES-ID missing     
**Description:**    
**Table:** AE, APC, OP    
**Data type:** logical    
**Values:** TRUE/1 = yes, FALSE/0 = no    
**Missing values**:     
**Derivation function:** `derive_missing()`    
**Derivation rules:**  `ifelse(is.na(ENCRYPTED_HESID), TRUE, FALSE)`    
**Dependencies:** ENCRYPTED_HESID    
**Usage:** Used to exclude episode with missing encrypted HES-ID when creating 
inpatient spells.    
**References:**    

## ELIXHAUSER_x
**Label:** Elixhause comorbidity score    
**Description:** 37 columns in total, including
* 31 columns are flags for individual conditions that form the Elixhauser score: 
ELIXHAUSER_CHF (congestive heart failure), ELIXHAUSER_CARIT (cardiac arrhythmias),
ELIXHAUSER_VALV (valvular disease), ELIXHAUSER_PCD (pulmonary circulation disorders),
ELIXHAUSER_PVD (peripheral vascular disorders), ELIXHAUSER_HYPUNC (hypertension,
uncomplicate), ELIXHAUSER_HYPC (hypertension, complicate), ELIXHAUSER_PARA (paralysis),
ELIXHAUSER_OND (neurological disorders), ELIXHAUSER_CPD (chronic pulmonary disease),
ELIXHAUSER_DIABUNC (diabetes, uncomplicated), ELIXHAUSER_DIABC (diabetes, complicated),
ELIXHAUSER_HYPOTHY (hypothyroidism), ELIXHAUSER_RF (renal failure), ELIXHAUSER_LD
(liver disease), ELIXHAUSER_PUD (peptic ulcer disease, excluding bleeding),
ELIXHAUSER_AIDS (AIDS/HIV), ELIXHAUSER_LYMPH (lymphoma), ELIXHAUSER_METACANC
(metastatic cancer), ELIXHAUSER_SOLIDTUM (solid tumour, without metastasis),
ELIXHAUSER_RHEUMD (rheumatoid arthritis/collaged vascular disease), ELIXHAUSER_COAG
(coagulopathy), ELIXHAUSER_OBES (obesity), ELIXHAUSER_WLOSS (weight loss),
ELIXHAUSER_FED (fluid and electrolyte disorders), ELIXHAUSER_BLANE (blood loss
anaemia), ELIXHAUSER_DANE (deficiency anaemia), ELIXHAUSER_ALCOHOL (alcohol abuse),
ELIXHAUSER_DRUG (drug abuse), ELIXHAUSER_PSYCHO (psychoses), ELIXHAUSER_DEPRE
(depression)
* ELIXHAUSER_SCORE (non-weighted version of the Charlson score)
* ELIXHAUSER_INDEX (non-weighted version of the grouped Charlson index)
* ELIXHAUSER_WSCORE_AHRQ (weighted version of the Elixhauser score using the AHRQ algorithm)
* ELIXHAUSER_WINDEX_AHRQ (weighted version of the grouped Charlson index using the AHRQ algorithm)
* ELIXHAUSER_WSCORE_VW (weighted version of the Charlson score using the algorithm in van Walraven)
* ELIXHAUSER_WINDEX_VW (weighted version of the grouped Charlson index using the algorithm in van Walraven)    
**Table:** APC        
**Data type:**     
**Values:**     
**Missing values**:     
**Derivation function:** `derive_comorbidities()`    
**Derivation rules:** Only derived if `comorbidities= TRUE`.    
**Dependencies:** all columns matching the pattern "DIAG_"    
**References:** also see the [documentation of the R package comorbidity](https://cran.r-project.org/web/packages/comorbidity/vignettes/comorbidityscores.html)        


## EPIBAD    
**Label:** Bad episode    
**Description:** Flag indicating a bad episode. This flag is set to TRUE if the 
duration of the episode is less than 0 days.    
**Table:** APC    
**Data type:** logical          
**Values:** TRUE/1 = bad episode, FALSE/0 = valid episode      
**Missing values**:     
**Derivation function:** `derive_epibad()`    
**Derivation rules:** `case_when(EPIDUR_CALC < 0 ~ TRUE,
                                 TRUE ~ FALSE)`    
**Dependencies:** EPIDUR_CALC     
**Usage:** Used to exclude bad episode when creating inpatient spells.     
**References:**    

## EPI_COUNT    
**Label:**  Episode count    
**Description:** The number of episodes within an inpatient spell.    
**Table:** APCS    
**Data type:** integer    
**Values:**     
**Missing values**:     
**Derivation function:** `create_inpatient_spells_table()`    
**Derivation rules:**  
**Dependencies:**        
**References:**    

## EPIDUR_CALC    
**Label:** Episode duration    
**Description:** The difference in days between episode start date and episode 
end date.    
**Table:** APC    
**Data type:** integer       
**Values:** An integer from 0 to infinity.     
**Missing values**: `NA`     
**Derivation function:** `derive_epidur_calc()`    
**Derivation rules:** `as.numeric(as.Date(EPIEND, format = "%Y-%m-%d") 
                                - as.Date(EPISTART, format = "%Y-%m-%d")`    
**Dependencies:** EPIEND, EPISTART      
**Usage:** Used to determine which episodes are invalid (EPIBAD).    
**References:**      

## EPIKEY_ADM    
**Label:**  Admission episode identifier of an inpatient spell    
**Description:** Episode identifier for the admission episode of an inpatient spell.    
**Table:** APCS    
**Data type:** integer     
**Values:**     
**Missing values**:     
**Derivation function:** `create_inpatient_spells_table()`    
**Derivation rules:** Equal to EPIKEY of the first episode (admission episode)
within a given inpatient spell.  
**Dependencies:** EPIKEY     
**References:** [Creating inpatient spells](doc/adr/creating_inpatient_spells.md)    


## EPIKEY_DIS    
**Label:**  Discharge episode identifier of an inpatient spell    
**Description:** Episode identifier for the discharge episode of an inpatient spell.    
**Table:** APCS    
**Data type:** integer     
**Values:**     
**Missing values**:     
**Derivation function:** `create_inpatient_spells_table()`    
**Derivation rules:** Equal to EPIKEY of the last episode (discharge episode)
within a given inpatient spell.  
**Dependencies:** EPIKEY     
**References:** [Creating inpatient spells](doc/adr/creating_inpatient_spells.md)    

## ETHNIC5
**Label:** Ethnicity (5 headings)    
**Description:** Ethnicity of the patient.     
**Table:** AE, APC, OP    
**Data type:** character     
**Values:** Asian/Asian British, Black/Black British, Chinese/Other, Mixed, 
White, Unknown      
**Missing values**: `NA`     
**Derivation function:** `derive_ethnicity()`    
**Derivation rules:**  White if ethnic category is A, B or C; Mixed if ethnic 
category is D, E, F or G; Asian/Asian British if ethnic category is H, J, K
or L; Black/Black British if ethnic category is M, N or P; Chinese/Other if 
ethnic category is R or S; Unknown otherwise.    
**Dependencies:** ETHNOS     
**References:** Office for National Statistics: Harmonised Concepts and Questions
for Social Data Sources: Primary Principles. Ethnic Group. 2015 [doi/link]

## FILENAME
**Label:** File name    
**Description:** Name of the raw data file from which the record was read.        
**Table:** AE, APC, CC, OP, ONS    
**Data type:** character    
**Values:**     
**Missing values**:     
**Derivation function:** `derive_extract()`    
**Derivation rules:**       
**Dependencies:** none    
**References:**

## IMD15_DECILE and IMD19_DECILE
**Label:**  IMD 2015 Decile Group and IMD 2019 Decile Group    
**Description:** Created using publicly available reference files by merging on LSOA11.    
**Table:** AE, APC, OP    
**Data type:** integer    
**Values:** An integer between 1 (most deprived) and 10 (least deprived).     
**Missing values**:     
**Derivation function:** `read_write_HES()`    
**Derivation rules:**  
**Dependencies:** LSOA11    
**References:**

## IMD15_RANK and IMD19_RANK
**Label:** IMD 2015 Overall Rank and IMD 2019 Overall Rank    
**Description:** IMD overall ranking of Lower-level Super Output Areas, based on
IMD 2015 or IMD 2019. Created using publicly available reference files by merging on LSOA11.       
**Table:** AE, APC, OP   
**Data type:** integer    
**Values:** An integer between 1 (most deprived) and 32482 (least deprived).     
**Missing values**:     
**Derivation function:** `read_write_HES()`    
**Derivation rules:**  
**Dependencies:** LSOA11    
**References:**

## IMPFRAILTY_x
**Label:** Frailty score (Imperial College)    
**Description:** 11 columns in total, including
* 9 columns are flags for conditions:
IMPFRAILTY_DEPANX (depression and anxiety), IMPFRAILTY_DELIRIUM (delirium), 
IMPFRAILTY_DEMENTIA (dementia), IMPFRAILTY_DEPENDENC (functional dependence), 
IMPFRAILTY_FALLSFRAX (falls and fractures), IMPFRAILTY_INCONT (incontinence),
IMPFRAILTY_MOBILITY (mobility problems), IMPFRAILTY_ULCERS (pressure ulcers), 
IMPFRAILTY_SENILITY (senility),
* IMPFRAILTY_SCORE (non-weighted version of the score)
* IMPFRAILTY_NORM_SCORE (score normalised to the number of conditions)    
**Table:** APC        
**Data type:**     
**Values:**     
**Missing values**:     
**Derivation function:** `derive_comorbidities()`     
**Derivation rules:** Only derived if `comorbidities= TRUE`.    
**Dependencies:** all columns matching the pattern "DIAG_"    
**References:** [Definition of the frailty score](doc/adr/frailty_score.md)     

## NEW_CIPS   
**Label:** New continuous inpatient spell    
**Description:** Flag indicating whether an inpatient spell was the start of 
a new continuous inpatient spell (CIPS). A continuous inpatient spell is defined as a 
sequence of inpatient spells with different hospital providers, from the patients 
admission to discharge to the usual place of residence. Spells are counted as 
being part of the same CIPS if there are up to three days, equivalent to two nights, 
between discharge from one provider and admission to another provider.    
**Table:** APCS  
**Data type:** logical           
**Values:** TRUE/1 = yes, FALSE/0 = no         
**Missing values**: `NA`     
**Derivation function:** `derive_new_cips()`    
**Derivation rules:** For spells that have the same encryped HES-ID and the 
episode end date of the previous spell is up to 3 days before the episode start 
date of the current spell NEW_CIPS is FALSE if **(1)** destination on discharge 
of the previous spell indicates it is a transfer or **(2)** source of admission 
of the current spell indicates it is a transfer or **(3)** the method of admission
of the current spell indicates it is a transfer. Otherwise, NEW_CIPS is set to 
TRUE.   
**Dependencies:** ADMIDATE, ADMIMETH, ADMISORC, DISDEST, ENCRYPED_HESID, EPIEND, 
EPISTART  
**Usage:** Used to create identifiers for CIPS.    
**References:** [Creating continuous inpatient spells](doc/adr/creating_continuous_inpatient_spells.md)    

## NEW_SPELL
**Label:** New inaptient spell    
**Description:** Flag indicating whether an inpatient episode was the start of 
a new inpatient spell. A spell is defined as a period of care with one hospital 
provider, from admission to discharge or transfer.    
**Table:** APC  
**Data type:** logical           
**Values:** TRUE/1 = yes, FALSE/0 = no         
**Missing values**: `NA`     
**Derivation function:** `derive_new_spell()`    
**Derivation rules:** If any of date of admission, encryped HES-ID, provider code (3 
character), episode start date, episode end date or record identifier are missing 
or the episode is not finished (EPISTAT not equal to 3, then NEW_SPELL is `NA`. 
For episodes that have the same encryped HES-ID and 
provider code (3 character) NEW_SPELL is FALSE if **(1)** the date of admission of the 
previous episode matches the date of admission of the current episode or **(2)**
the episode start date of the previous episode matches the episode start date of 
the current episode or **(3)** the method of discharge of the previous episode is
a transfer (DISMET is equal to 8 or 9) and the episode start date of the previous
episode matches the episode start date of the current episode. Otherwise, NEW_SPELL
is set to TRUE.   
**Dependencies:** ADMIDATE_FILLED, ADMIDATE_MISSING, DISMETH, ENCRYPTED_HESID, 
ENCRYPTED_HESID_MISSING, EPIEND, EPIORDER, EPIKEY, EPISTART, EPISTAT, PROCODE3, 
PROCODE3_MISSING, TRANSIT    
**Usage:** Used to create identifiers for spells.    
**References:** [Creating inpatient spells](doc/adr/creating_inpatient_spells.md)     

## PROCODE3    
**Label:**  Provider code (3 character)    
**Description:** Organisation code of the organisation acting as the health care
provider.    
**Table:** AE, APC, OP    
**Data type:** character    
**Values:**     
**Missing values**: `NA`    
**Derivation function:** `derive_procode3()`    
**Derivation rules:** Extract the first three characters from the provider code.    
**Dependencies:** PROCODE     
**References:**    

## PROCODE3_FIRST_CIPS    
**Label:**  Provider code (3 character) of the first spell in a CIPS   
**Description:** Organisation code of the organisation acting as the health care
provider during the first inpatient spell in a continuous inpatient spell.    
**Table:** APCC    
**Data type:** character    
**Values:**     
**Missing values**: `NA`    
**Derivation function:** `create_cips_table()`    
**Derivation rules:**   
**Dependencies:** PROCODE     
**References:** [Creating continuous inpatient spells](doc/adr/creating_continuous_inpatient_spells.md)    

## PROCODE3_LAST_CIPS    
**Label:**  Provider code (3 character) of the last spell in a CIPS   
**Description:** Organisation code of the organisation acting as the health care
provider during the last inpatient spell in a continuous inpatient spell.    
**Table:** APCC    
**Data type:** character    
**Values:**     
**Missing values**: `NA`    
**Derivation function:** `create_cips_table()`    
**Derivation rules:**   
**Dependencies:** PROCODE     
**References:** [Creating continuous inpatient spells](doc/adr/creating_continuous_inpatient_spells.md)    

## PROCODE3_MISSING    
**Label:**  Provider code (3 character)  missing    
**Description:** Flag indicating whether the provider code is missing or not.    
**Table:** AE, APC, OP     
**Data type:** logical        
**Values:** TRUE/1 = yes, FALSE/0 = no    
**Missing values**:     
**Derivation function:** `derive_missing()`     
**Derivation rules:**  `ifelse(is.na(PROCODE3), TRUE, FALSE)`    
**Dependencies:** PROCODE3   
**Usage:** Used to exclude episode with missing provider code when creating 
inpatient spells.     
**References:**

## ROWCOUNT
**Label:** Column used during generation of spell and CIPS identifiers.     
**Description:** 
**Table:** APC, APCS        
**Data type:** integer    
**Values:**       
**Missing values**:     
**Derivation function:** `derive_new_spell()` and `derive_new_cips()`   
**Derivation rules:**     
**Dependencies:**    
**Usage:**  Don't use.
**References:**     

## ROWQUALITY
**Label:** Row quality     
**Description:** Count of non-missing variables per record, based on a defined
number of variables. A higher score indicates a row with fewer missing values.     
**Table:** AE, APC, OP        
**Data type:** integer    
**Values:**    
**[AE]** integer between 0 and 35    
**[APC]** integer between 0 and 23   
**[OP]** integer between 0 and 8    
**Missing values**:     
**Derivation function:** `derive_row_quality()`    
**Derivation rules:**  Count number of non-missing values (not `NA`) per row 
across the columns listed below. Only derived if `duplicates = TRUE`.      
**Dependencies:**    
**[AE]** AEARRIVALMODE, AEATTENDCAT, AEATTENDDISP, AEDEPTTYPE, ARRIVALAGE, 
ARRIVALTIME, CONCLTIME, DEPTIME, INITTIME, INVEST_01 to INVEST_12, TREAT_01 to
TREAT_12    
**[APC]** ADMIMETH, ADMISORC, DIAG_01 to DIAG_14, DISDEST, DISMETH, MAINSPEF, 
STARTAGE, SITETRET, TRETSPEF, OPERTN_01     
**[OP]** APPTAGE, FIRSTATT, OUTCOME, PRIORITY, REFSOURC, SERVTYPE, SITETRET,
STAFFTYP    
**Usage:** This variable is used to identify and flag duplicate records (DUPLICATE).    
**References:**     

## SEEN   
**Label:** Seen A&E attendance    
**Description:** Flag indicating whether the patient was seen before leaving the
A&E department. Automatically set to FALSE for duplicate records.   
**Table:** AE   
**Data type:** logical     
**Values:** TRUE/1 = yes, FALSE/0 = no        
**Missing values**:     
**Derivation function:** `update_var()`    
**Derivation rules:** Set to TRUE where AEATTENDDISP is not equal to 12 or 13 
and DUPLICATE = FALSE, else set to FALSE. Only derived if `duplicates = TRUE`.     
**Dependencies:** AEATTENDDISP, DUPLICATE    
**Usage:** To count A&E attendances that were seen.    
**References:**   

## SPELL_ID
**Label:** Inpatient spell identifier    
**Description:** An identifier for each inpatient spell, which is unique in 
combination with ENCRYPTED_HESID. A spell is defined as a period of care with one hospital 
provider, from admission to discharge or transfer.     
**Table:** APCS        
**Data type:** integer    
**Values:**     
**Missing values**:     
**Derivation function:** `derive_spell_id()`    
**Derivation rules:** SPELL_ID is set to 1 for episodes belonging to the first 
inpatient spell of each patient, and increased by one for episodes belonging to 
subsequent spells.    
**Dependencies:** ENCRYPTED_HESID, EPIEND, EPIKEY, EPIORDER, EPISTART, NEW_SPELL,
PROCODE3, TRANSIT    
**References:** [Creating inpatient spells](doc/adr/creating_inpatient_spells.md)     

## TRANSIT    
**Label:**  Transit    
**Description:** This variable allows identification and sorting of same-day patient transfers.    
**Table:** APC    
**Data type:** integer    
**Values:** 0 = admission is not a transfer and discharge is not a transfer (default value),
1 = admission is not a transfer and discharge is a transfer, 2 = admission is a 
transfer and discharge is a transfer, 3 = admission is a transfer 
and discharge is not a transfer    
**Missing values**:     
**Derivation function:** `derive_transit()`    
**Derivation rules:**  `TRANSIT = case_when(!(ADMISORC %in% c(51,52,53)) &    
                                            (DISDEST %in% c(51,52,53)) &    
                                            !(ADMIMETH %in% c(67,81)) ~ 1,     
                                            ((ADMISORC %in% c(51,52,53)) | (ADMIMETH %in% c(67,81))) &    
                                            (DISDEST %in% c(51,52,53)) ~ 2,    
                                            ((ADMISORC %in% c(51,52,53)) | (ADMIMETH %in% c(67,81))) &    
                                            !(DISDEST %in% c(51,52,53)) ~ 3,    
                                            TRUE ~ 0)`    
**Dependencies:** ADMIMETH, ADMISORC, DISDEST    
**Usage:** This variable is used to identify and flag duplicate records (DUPLICATE) and to 
create inpatient spells and continuous inpatient spells.    
**References:** Centre for Health Economics, The University of York    

## UNPLANNED    
**Label:**  Unplanned A&E attendance     
**Description:** Flag indicating whether the A&E attendance was unplanned.   
Automatically set to FALSE for duplicate records.    
**Table:** AE   
**Data type:** logical        
**Values:** TRUE/1 = yes, FALSE/0 = no        
**Missing values**:     
**Derivation function:** `update_var()`    
**Derivation rules:** Set to TRUE where AEATTENDCAT not equal to 2 and DUPLICATE 
= FALSE, else set to FALSE. Only derived if `duplicates = TRUE`.    
**Dependencies:** AEATTENDCAT, DUPLICATE   
**Usage:** To count A&E attendances that were unplanned.    
**References:**    

## UNPLANNED_SEEN   
**Label:**     
**Description:** Flag indicating whether the A&E attendance was unplanned and ended
in the patient being seen. Automatically set to FALSE for duplicate records.        
**Table:** AE   
**Data type:** logical        
**Values:** TRUE/1 = yes, FALSE/0 = no        
**Missing values**:     
**Derivation function:** `update_var()`    
**Derivation rules:** Set to TRUE where UNPLANNED = 1 and SEEN = 1, else set to 
FALSE. Only derived if `duplicates = TRUE`.      
**Dependencies:** UNPLANNED, SEEN    
**Usage:** To count A&E attendances that were unplanned and seen.    
**References:**    



