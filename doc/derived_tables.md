# Documentation for derived database tables
   
The data pipeline expects any of following raw data tables:    
**AE** - HES Accidents & Emergencies    
**APC** - HES Admitted Patient Care    
**CC** - HES Critical Care    
**OP** - HES Outpatients    
**ONS** - ONS Mortality Records (+ HES bridge file)    

The tables listed below are derived during the `update_database` stage of the 
pipeline. They are created only if their dependencies are present in the raw 
data table.    

**APCS** - HES Admitted Patient Care Inpatient Spells    
For documentation on how inpatient spells are derived see [].    

**APCC** - HES Admitted Patient Care Continuous Inpatient Spells    
For documentation on how inpatient spells are derived see [].    

Once the `update_database` stage is complete, the pipeline also creates high-level
summaries of clean data, including:    

**DATASET_SUMMARY_STATS** - Number of records per dataset, percentage of 
records flagged as duplicates   

**FILE_SUMMARY_STATS** - Number of records per dataset and raw data file, percentage of 
records flagged as duplicates   

**[dataset]_SUMMARY_STATS** - Summary statistics for each variable per dataset, percentage of
missing variables per variable. 