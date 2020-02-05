library(dplyr)
library(tidylog)
source("src/clean.R")

# Derive column containing filename data was extracted from.
# Requires a dataframe and a filename as a string.
# Returns a modified dataframe.
derive_extract <- function(data, filename) {
  return(mutate(data, "FILENAME" = filename))
}


# Derive a column flagging missing data in another column.
# Requires a dataframe, a column to check for NAs and a new column 
# name, both as strings.
# Returns a modified dataframe.
derive_missing <- function(data, missing_col, new_col) {
  return(mutate_if_present(data, c(missing_col), 
                    funs(!! paste0(new_col) := (ifelse(is.na(eval(parse(text=missing_col))), TRUE, FALSE)))))
}


# Derive ETHNIC5 column, summarising patient ethnicity, if ETHNOS column present.
# Requires a dataframe.
# Returns a modifed dataframe.
derive_ethnicity <- function(data) {
  return(mutate_if_present(data, "ETHNOS", 
                    funs(ETHNIC5 = 
                           case_when(ETHNOS == "A" |
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
  return(mutate_if_present(data, "PROCODE", funs(PROCODE3 = substr(., 1, 3))))
}


# Derives additional columns for all HES datasets.
# Requires a dataframe and a filename.
# Returns a modified dataframe.
derive_HES <- function(data, filename) {
  return(data %>%
           derive_extract(filename) %>%
           derive_missing("ENCRYPTED_HESID", "ENCRYPTED_HESID_MISSING") %>%
           derive_missing("ARRIVALDATE", "ARRIVALDATE_MISSING") %>%
           derive_missing("ADMIDATE", "ADMIDATE_MISSING") %>%
           derive_missing("APPTDATE", "APPTDATE_MISSING") %>%
           derive_ethnicity() %>%
           derive_procode3() %>%
           derive_missing("PROCODE3", "PROCODE3_MISSING"))
}

