
# Derive column containing filename data was extracted from.
# Requires a dataframe and a filename as a string.
# Returns a modified dataframe.
derive_extract <- function(data, filename) {
  return(mutate(data, "FILENAME" = filename))
}


# Add new named column, with single value (for later processing).
# Requires a dataframe,a list of columns to test for and a value.
# Returns a modified dataframe.
derive_new <- function(data, cols, new_col, v) {
  return(if(all(cols %in% names(data))) {
    mutate(data, !!new_col := v)
  } else {
    data
  })
}


# Derive a column flagging missing data in another column.
# Requires a dataframe, a column to check for NAs, a new column 
# name, both as strings and a log file as a string.
# NB tidylog::mutate cannot be used here because of the way the arguments
# are passed. Logging of new variables therefore added manually. 
# Returns a modified dataframe.
derive_missing <- function(data, missing_col, new_col, tidy_log) {
  if(missing_col %in% names(data)) {
    data <- dplyr::mutate(data, !!new_col := ifelse(is.na(!!rlang::sym(missing_col)), TRUE, FALSE))
    sink(tidy_log, append = TRUE)
    cat(paste0("mutate_at: new variable '", new_col, "'\n"))
    sink()
  }
  return(data)
}


# Derive ETHNIC5 column, summarising patient ethnicity, if ETHNOS column present.
# Requires a dataframe.
# Returns a modifed dataframe.
derive_ethnicity <- function(data) {
  return(mutate_if_present(data, cols = "ETHNOS", 
                    fn = list(ETHNIC5 = 
                           ~case_when(ETHNOS == "A" |
                                       ETHNOS == "B" |
                                       ETHNOS == "C" ~ "White",
                                     ETHNOS == "D" |
                                       ETHNOS == "E" |
                                       ETHNOS == "F" |
                                       ETHNOS == "G" ~ "Mixed",
                                     ETHNOS == "H" |
                                       ETHNOS == "J" |
                                       ETHNOS == "K" |
                                       ETHNOS == "L" ~ "Asian/Asian British",
                                     ETHNOS == "M" |
                                       ETHNOS == "N" |
                                       ETHNOS == "P" ~ "Black/Black British",
                                     ETHNOS == "R" |
                                       ETHNOS == "S" ~ "Chinese/Other",
                                     is.na(ETHNOS) ~ "Unknown"))))
}


# Derive PROCODE3 column, as the first three letters of PROCODE, if present.
# Requires a dataframe.
# Returns a modified dataframe.
derive_procode3 <- function(data) {
  return(mutate_if_present(data, cols = "PROCODE", fn = list(PROCODE3 = ~substr(., 1, 3))))
}


# Derive ROWQUALITY column, by scoring for NAs in a selection of columns, if all present.
# Requires a dataframe and a column name or vector of column names as strings
# Returns a modifed dataframe.
derive_row_quality <- function(data, cols) {
  if(all(cols %in% names(data))) {
    data <-  data %>% 
      mutate(ROWQUALITY = data %>%
             dplyr::select(one_of(cols)) %>%
             future_map(function(x) !is.na(x)) %>%
             future_pmap_dbl(sum))
  } else {
    data
  }
  return(data)
}


# Derive TRANSIT column, by testing values in ADMISORC, ADMIMETH & DISDEST.
# Derived values:
# 0 - the default, corresponding to admission not being a transfer in and 
# discharge not being a transfer out.
# 1 - admission is any other than a transfer in and discharge is a transfer
# out.
# 2 - admission is a transfer in and discharge is a transfer out.
# 3 - admission is a transfer in and discharge is any other than transfer
# out.
# N.B. `case_when()`` evaluates arguments in order. This means that TRANSIT 
# = 2 (transfer in/transfer out) supersedes TRANSIT = 3 (transfer in/not a 
# transfer out). Transit 0 is assigned by default if none of the other 
# conditions match.
# Requires a dataframe.
# Returns a modified dataframe.
derive_transit <- function(data) {
  if(all(c("ADMISORC", "ADMIMETH", "DISDEST") %in% names(data))) {
    mutate(data, TRANSIT = case_when(!(ADMISORC %in% c(51,52,53)) &
                                       (DISDEST %in% c(51,52,53)) &
                                       !(ADMIMETH %in% c(67,81)) ~ 1,
                                     ((ADMISORC %in% c(51,52,53)) | (ADMIMETH %in% c(67,81))) &
                                       (DISDEST %in% c(51,52,53)) ~ 2,
                                     ((ADMISORC %in% c(51,52,53)) | (ADMIMETH %in% c(67,81))) &
                                       !(DISDEST %in% c(51,52,53)) ~ 3,
                                     TRUE ~ 0))
  } else {
    data
  }
}

  
# Derive ADMIDATE_FILLED column, by assessing whether ADMIDATE is present or missing.
# If missing but EPISTART is present, it is the first episode and not a transfer in
# impute ADMIDATE from EPISTART.
# Requires a dataframe.
# Returns a modifed dataframe.
derive_admidate_filled <- function(data) {
  return(if(all(c("ADMIDATE", "EPISTART", "EPIORDER", "ADMIMETH", "ADMISORC")
                %in% names(data))) {
    mutate(data, ADMIDATE_FILLED = case_when(!is.na(ADMIDATE) ~ ADMIDATE,
                                             is.na(ADMIDATE) &
                                               !is.na(EPISTART) &
                                               EPIORDER == 1 &
                                               !(ADMIMETH %in% c(67,81)) &
                                               !(ADMISORC %in% c(51,52,53)) ~ EPISTART))
  } else {
    data
  })
}


# Derive EPIBAD column, by assessing whether an episode was less than a day.
# Requires a dataframe.
# Returns a modified dataframe.
derive_epi_bad <- function(data) {
  return(mutate_if_present(data, cols = "EPIDUR_CALC", 
                           fn = list(EPI_BAD = ~case_when(EPIDUR_CALC < 0 ~ TRUE,
                                                    TRUE ~ FALSE))))
}


# Derive DOD_FILLED column, by assessing whether DOD is present or missing.
# If missing but DOR is present, impute DOD from DOR
# Requires a dataframe.
# Returns a modifed dataframe.
derive_dod_filled <- function(data) {
  return(if(all(c("DOD", "DOR")
                %in% names(data))) {
    mutate(data, DOD_FILLED = case_when(!is.na(DOD) ~ DOD,
                                        is.na(DOD) & !is.na(DOR) ~ DOR))
  } else {
    data
  })
}

# Derive EPIDUR_CALC column, by calculating the 
# Requires a dataframe.
# Returns a modifed dataframe.
derive_epidur_calc <- function(data) {
  return(if(all(c("EPISTART", "EPIEND")
                %in% names(data))) {
    mutate(data, EPIDUR_CALC = as.numeric(as.Date(EPIEND, format = "%Y-%m-%d") 
                                          - as.Date(EPISTART, format = "%Y-%m-%d")))
  } else {
    data
  })
}

# Derive EPI_VALID column, by defining where an episode is valid.
# Requires a dataframe.
# Returns a modifed dataframe.
derive_epi_valid <- function(data) {
  return(if(all(c("ENCRYPTED_HESID_MISSING", "ADMIDATE_MISSING", "PROCODE3_MISSING",
                  "EPISTAT", "EPIKEY", "EPISTART", "EPIEND") %in% names(data))) {
    mutate(data, EPI_VALID = ifelse(ENCRYPTED_HESID_MISSING == FALSE &
                                    ADMIDATE_MISSING == FALSE &
                                    PROCODE3_MISSING == FALSE &
                                    EPISTAT == 3 &
                                    !is.na(EPIKEY) &
                                    !is.na(EPISTART) &
                                    !is.na(EPIEND), TRUE, FALSE))
  } else {
    data
  })
}



# Derives additional columns for all HES datasets.
# Requires a dataframe, a filename as a string, a log file as a string,
# a named list of vectors defining columns used as the basis for rowquality per
# datasets (eg list("AE" = c(cols), ...)), a named list of named lists defining 
# columns to use for deduplication per dataset (eg list("AE" = list("group" = cols1, "order" = cols2), ...)).
# Returns a modified dataframe.

derive_HES <- function(data, filename, table_name, tidy_log, duplicates, rowquality_cols, duplicate_cols) {
  data <- data %>%
    derive_extract(filename) %>%
    derive_missing(missing_col = "ENCRYPTED_HESID", new_col = "ENCRYPTED_HESID_MISSING", tidy_log) %>%
    derive_missing(missing_col = "ARRIVALDATE", new_col = "ARRIVALDATE_MISSING", tidy_log) %>%
    derive_missing(missing_col = "APPTDATE", new_col = "APPTDATE_MISSING", tidy_log) %>%
    derive_ethnicity() %>%
    derive_procode3() %>%
    derive_missing(missing_col = "PROCODE3", new_col = "PROCODE3_MISSING", tidy_log) %>%          
    derive_transit() %>%
    derive_admidate_filled() %>%
    derive_missing(missing_col = "ADMIDATE_FILLED", new_col = "ADMIDATE_MISSING", tidy_log) %>%
    derive_epidur_calc() %>% 
    derive_epi_bad() %>% 
    derive_epi_valid() %>% 
    derive_comorbidities(table_name) %>%
    derive_new(cols = "DISDATE", new_col = "DISDATE_MISSING", v = FALSE)
  

  if(duplicates == TRUE){
    data <-  data %>%
      derive_row_quality(APC_cols) %>%
      derive_row_quality(AE_cols) %>%
      derive_row_quality(OP_cols) %>% 
      derive_new(cols = c(duplicate_cols$AE$group, duplicate_cols$AE$order), new_col = "DUPLICATE", v = FALSE) %>%
      derive_new(cols = c(duplicate_cols$APC$group, duplicate_cols$APC$order), new_col = "DUPLICATE", v = FALSE) %>%
      derive_new(cols = c(duplicate_cols$OP$group, duplicate_cols$OP$order), new_col = "DUPLICATE", v = FALSE)%>%
      derive_new(cols = c("AEATTENDCAT", "DUPLICATE"), new_col = "UNPLANNED", v = FALSE) %>% 
      derive_new(cols = c("AEATTENDDISP", "DUPLICATE"), new_col = "SEEN", v = FALSE) %>% 
      derive_new(cols = c("AEATTENDCAT", "DUPLICATE", "UNPLANNED", "SEEN"), 
               new_col = "UNPLANNED_SEEN", v = FALSE)
    }

  return(data)
}

