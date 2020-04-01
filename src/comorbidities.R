
# Derive flags for comorbidities and compute Charlson and Elixhause 
# comorbidity scores
# Requires a dataframe
# Returns a modified dataframe.
derive_comorbidities <- function(data, table_name){
  
  if(table_name %in% c("AE", "APC") & any(str_detect(names(data), "DIAG_")) == TRUE){
    
    if(table_name == "AE"){id_cols = c("ENCRYPTED_HESID", "AEKEY")}
    if(table_name == "APC"){id_cols = c("ENCRYPTED_HESID", "EPIKEY")}
    
    diags <- data  %>% 
      select_at(vars(id_cols, contains("DIAG_"))) %>% 
      unite("id", id_cols, sep = "_") %>% 
      pivot_longer(cols = contains("DIAG_"), names_to = "temp", values_to = "ICD10code") %>% 
      select(-temp)
    
    charlson <- comorbidity(x = diags, id = "id", code = "ICD10code", 
                            score = "charlson", icd = "icd10", assign0 = FALSE) %>% 
      rename_all(toupper) %>% 
      rename_all(list(~str_c("CHARLSON_", .)))
    
    elixhauser <- comorbidity(x = diags, id = "id", code = "ICD10code", 
                              score = "elixhauser", icd = "icd10", assign0 = FALSE) %>% 
      rename_all(toupper) %>% 
      rename_all(list(~str_c("ELIXHAUSER_", .)))
    
    imperial_frailty <- calculate_Imperial_eFI(x = diags, id = "id", code = "ICD10code") %>% 
      rename_all(toupper) %>% 
      rename_all(list(~str_c("IMPFRAILTY_", .)))
  
    comorbidities <- charlson %>% 
      left_join(elixhauser, by = c("CHARLSON_ID" = "ELIXHAUSER_ID")) %>% 
      left_join(imperial_frailty, by = c("CHARLSON_ID" = "IMPFRAILTY_ID")) %>% 
      separate("CHARLSON_ID", into = id_cols)
    
    data <- data %>% 
      left_join(comorbidities, by = id_cols)
  }
  
  return(data)
}

# Derive flags for comorbidities in custom Imperial frailty score and compute score
# Requires a dataframe, a column with unique IDs, a column with ICD 10 codes and
# a boolean indicating whether diagnosis codes need to be tidied (convert to upper case,
# remove punctuation and spaces), default is true.
# Returns a modified dataframe.
calculate_Imperial_eFI <- function (x, id, code, tidy.codes = TRUE){
  
  if (tidy.codes == TRUE){ 
    x <- x %>% 
      mutate(!!code := toupper(!!rlang::sym(code)),
             !!code := gsub("[[:punct:]]", "", !!rlang::sym(code)),
             !!code := gsub(" ", "", !!rlang::sym(code)))
  }
  
  ### --- Define frailty categories 
  # Anxiety and depression 
  depanx_codes <- c("F32.*","F33.*","F38.*","F41.*","F43.*","F44.*")
  
  # Delirium
  delirium_codes <-c("F05.*")
  
  # Dementia
  dementia_codes <- c("F00.*","F01.*","F02.*","F03.*","F04.*","R41.*")
  
  # Functional dependence
  dependence_codes <- c("Z74.*","Z75.*")
  
  # Falls and fractures
  fallsfrax_codes <- c("R55.*","S32.*","S33.*","S42.*","S43.*","S62.*","S72.*","S73.*","W.*")
  # note: there are a number of fractures causing reduced mobility missing here
  
  # Incontinence
  incont_codes <- c("R15.*","R32.*")
  
  # Mobility problems
  mobility_codes <- c("R26.*","Z74.*")
  
  # Pressure ulcers
  ulcers_codes <- c("L89.*")
  
  # Senility 
  senility_codes <- c("R54.*")
  
  detect_diagnoses <- function(x, codes){
    return(str_detect(replace_na(x, ""), str_c(codes, collapse = "|")))
  }
  
  x <- x %>% 
    mutate(DEPANX := detect_diagnoses(!!rlang::sym(code), depanx_codes),
           DELIRIUM := detect_diagnoses(!!rlang::sym(code),delirium_codes),
           DEMENTIA := detect_diagnoses(!!rlang::sym(code),dementia_codes),
           DEPENDENCE := detect_diagnoses(!!rlang::sym(code),dependence_codes),
           FALLSFRAX := detect_diagnoses(!!rlang::sym(code),fallsfrax_codes),
           INCONT := detect_diagnoses(!!rlang::sym(code),incont_codes),
           MOBILITY := detect_diagnoses(!!rlang::sym(code),mobility_codes),
           ULCERS := detect_diagnoses(!!rlang::sym(code),ulcers_codes),
           SENILITY := detect_diagnoses(!!rlang::sym(code),senility_codes))
  
  x <- x %>% 
    select(-!!code) %>% 
    group_by(!!rlang::sym(id)) %>% 
    summarise_all(~ any(.)) %>% 
    mutate(SCORE := rowSums(select(., -!!rlang::sym(id))),
           NORM_SCORE = round(SCORE / (ncol(.)-1), 2))
  
  return(x)
}
