# Definition of the Imperial College frailty score IMPFRAILTY

## Context

This score is intended to be a simple method to identify frailty in Admitted Patient Care records. 

The diagnosis codes used are based on [Soong *et al.*, 2015](https://bmjopen.bmj.com/content/bmjopen/5/10/e008457.full.pdf) and calculated similarly to the 
electronic Frailty Index (eFI, [Clegg *et al.*, 2016](https://academic.oup.com/ageing/article/45/3/353/1739750)).

## Definition

The score is based on ICD-10 codes and the following frailty categories were used:
* Anxiety and depression: F32, F33, F38, F41, F43, F44
* Delirium: F05
* Dementia: F00, F01, F02, F03, F04, R41
* Functional dependence: Z74, Z75
* Falls and fractures: R55, S32, S33, S42, S43, S62, S72, S73, W00-W99
  (note: there are a number of fractures causing reduced mobility missing here)
* Incontinence: R15, R32
* Mobility problems: R26, Z74
* Pressure ulcers: L89
* Senility: R54

Frailty categories are scores as 0 if none of the corresponding codes is found in any of the HES diagnosis columns (DIAG_NN) or as 1 if one ore more of the corresponding codes are found.

The frailty score is the sum of the scored frailty categories (0-9). The normalised frailty score is the sum of the scored frailty categories divided by the number of categories. 

## Status

Implemented in the [HES cleaning pipeline](https://github.com/HFAnalyticsLab/HES_pipeline) used to prepare the raw data for this project (see [src/comorbidities.R](https://github.com/HFAnalyticsLab/HES_pipeline/blob/master/src/comorbidities.R)), potential future optimisation.
