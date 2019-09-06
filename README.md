# Hospital Episode Statistics (HES) pipeline

Development of an open-source R pipeline to clean and process patient-level HES data, with the aim to produce analysis-ready datasets for a defined programme of analyses. 

#### Project Status: Planning

## Project Description
[Hospital Episode Statistics (HES)](https://digital.nhs.uk/data-and-information/data-tools-and-services/data-services/hospital-episode-statistics) is a database containing details of all hospital admissions, A&E attendances and outpatient appointments at NHS hospitals in England.

Before it can be used for analysis, HES data requires extensive cleaning (eg recoding of missing values, deduplication) and quality control, and certain key flags and variables need to be constructed. The complexity of HES, the large number of variables and the size of the data sets can make this a challenging task. 

This cleaning and processing workflow will be designed to ensure that HES data is procssed consistently and reproduciblty and that every one of our pre-approved analysis project works with the same clean data set. 

## Data source
We are planning to use HES linked to Civil Registrations (deaths) covering the last 10 years as well as quarterly data updates for the next 3 years. Our data application is currently under review by the NHS Digital [Data Access Request Service (DARS)](https://digital.nhs.uk/services/data-access-request-service-dars). 

The data will be accessed in The Health Foundation's Secure Data Environment, which is a secure data analysis facility (accredited for the ISO27001 information security standard, and recognised for the NHS Digital Data Security and Protection Toolkit). No information that could directly identify a patient or other individual will be used. 

## How does it work?
As the data used for this analysis is not publically available, the code cannot be used to replicate the analysis on this dataset. However, with modifications the code will be able to be used on other patient-level HES extracts to prepare the dataset for analysis. 

## License
This project is licensed under the [MIT License](LICENSE.md).

