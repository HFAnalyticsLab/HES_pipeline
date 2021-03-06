
# If a column is present in dataframe apply provided function.
# Warnings generated by 'one_of' when col not found are supressed.
# Requires a dataframe, a column name as a string and a function to
# recursively apply to the column if present.
# Returns dataframe with modifed column.
mutate_if_present <- function(data, cols, fn) {
  return(suppressWarnings(data %>% mutate_at(vars(one_of(cols)), fn)))
}


# Parse columns (or single column) converting a specifc value to NA
# Requires a dataframe, a vector of column names as strings and a value to convert
# to NA.
# Returns a modified dataframe.
convert_to_NA <- function(data, cols, v) {
  return(data %>% mutate_if_present(cols, ~na_if(., v)))
}


# Parse columns (or single column) converting strings to date format, 
# e.g. 2010-31-01.
# Requires  a dataframe, a vector of column names as strings and a date format e.g. "%Y%m%d.
# Returns a modified dataframe.
convert_date <- function(data, cols) {
  return(data %>% mutate_if_present(cols, as.Date))
}


# Parse columns (or single column) converting values to integers.
# Requires  a dataframe, and a vector of column names as strings.
# Returns a modified dataframe.
convert_to_int <- function(data, cols) {
  return(mutate_if_present(data, cols, as.integer))
}


# Parse columns (or single column) converting a set of values (or single
# value) to a new set of values (or single value).
# Requires a dataframe, a vector of column names as strings, a vector of values to be replaced 
# and a vector of values to replace with.
# Returns a modified dataframe.
convert_vals <- function(data, cols, old_vals, new_vals) {
  return(data %>% mutate_if_present(cols, ~plyr::mapvalues(., old_vals, new_vals)))
}


# Generates a vector of headers corresponding to the provided string with numbers 01 to 
# n appended, n times
# Requires a string and a maximum number
# Returns a character vector
generate_numbered_headers <- function(string, n) {
  return(c(str_c(string, "0", 1:9), str_c(string, 10:n)))
}


# Parse columns, where present, into required data formats.
# Requires a dataframe.
# Returns a modifed dataframe.
parse_HES <- function(data) {
  return(data %>% 
           convert_to_NA(c("ADMINCAT", "ADMINCATST", "ADMISORC", "DISDEST", "RTTPERSTAT", "EPIORDER"), 98) %>%
           convert_to_NA(c("ADMINCAT", "ADMINCATST", "ADMISORC" ,"CARERSI", "DISDEST",
                           "EPIORDER", "LOCCLASS", "REFSOURC", "RTTPERSTAT", "STAFFTYP", "AEATTENDDISP",
                           "AEDEPTTYPE", "AEINCLOCTYPE", "AEPATGROUP", "AEREFSOURCE", "ccapcrel"), 99) %>%
           convert_to_NA(c("ATENTYPE"), 13) %>%
           convert_to_NA(c("AEARRIVALMODE", "AEATTENDCAT", "CLASSPAT", "DISMETH", "INTMANIG",
                           "NEOCARE", "OPERSTAT", "ATTENDED", "OUTCOME", "PRIORITY", "SERVTYPE", 
                           "STAFFTYP"), 9) %>%
           convert_to_NA(c("CLASSPAT", "INTMANIG", "NEOCARE", "OPERSTAT", "STAFFTYP"), 8) %>%
           convert_to_NA(c("SEX"), 0) %>%
           convert_to_NA(c("ARRIVALTIME", "CONCLTIME", "DEPTIME", "INITTIME", "TRETTIME"), 3000) %>%
           convert_to_NA(c("ARRIVALTIME", "CONCLTIME", "DEPTIME", "INITTIME", "TRETTIME"), 4000) %>%
           convert_to_NA(c("FIRSTATT"), "9") %>%
           convert_to_NA(c("ADMIMETH"), "98") %>%
           convert_to_NA(c("ADMIMETH", "ETHNOS"), "99") %>%
           convert_to_NA(c("PROCODE", "SITETRET"), "89999") %>%
           convert_to_NA(c("PROCODE", "SITETRET"), "89997") %>%
           convert_to_NA(c("AEKEY"), "0") %>%
           convert_to_NA(c("ETHNOS", "FIRSTATT"), "X") %>%
           convert_to_NA(c("ETHNOS"), "Z") %>%
           convert_to_NA(generate_numbered_headers("OPERTN_", n = 24), "-") %>%
           convert_to_NA(c(c("ARRIVALDATE", "ADMIDATE", "DISDATE", "DISREADYDATE", 
                           "ELECDATE", "EPIEND", "EPISTART",  "RTTPEREND", "RTTPERSTART", 
                           "SUBDATE", "APPTDATE", "DNADATE", "REQDATE", "DOD", "DOR",
                           "DISDATE", "ccdisdate", "ccdisrdydate", "ccstartdate"),
                           generate_numbered_headers("OPDATE_", n = 24)), 
                         "1800-01-01") %>%
           convert_to_NA(c(c("ARRIVALDATE", "ADMIDATE", "DISDATE", "DISREADYDATE", 
                           "ELECDATE", "EPIEND", "EPISTART", "RTTPEREND", "RTTPERSTART", 
                           "SUBDATE", "APPTDATE", "DNADATE", "REQDATE", "DOD", "DOR",
                           "DISDATE", "ccdisdate", "ccdisrdydate", "ccstartdate"),
                           generate_numbered_headers("OPDATE_", n = 24)), 
                         "1801-01-01") %>%
           convert_to_NA(c(c("ARRIVALDATE", "ADMIDATE", "DISDATE", "DISREADYDATE", 
                           "ELECDATE", "EPIEND", "EPISTART", "RTTPEREND", "RTTPERSTART", 
                           "SUBDATE", "APPTDATE", "DNADATE", "REQDATE", "DOD", "DOR",
                           "DISDATE", "ccdisdate", "ccdisrdydate", "ccstartdate"),
                           generate_numbered_headers("OPDATE_", n = 24)), 
                         "1600-01-01") %>%
           convert_to_NA(c(c("ARRIVALDATE", "ADMIDATE", "DISDATE", "DISREADYDATE", 
                           "ELECDATE", "EPIEND", "EPISTART", "RTTPEREND", "RTTPERSTART", 
                           "SUBDATE", "APPTDATE", "DNADATE", "REQDATE", "DOD", "DOR",
                           "DISDATE", "ccdisdate", "ccdisrdydate", "ccstartdate"),
                           generate_numbered_headers("OPDATE_", n = 24)), 
                         "1582-10-15") %>%
           convert_to_NA(c("APPTDATE", "ARRIVALDATE"), "18000101") %>%
           convert_to_NA(c("APPTDATE", "ARRIVALDATE"), "18010101") %>%
           convert_to_NA(c(c("DOMPROC", "GPPRAC", "MAINSPEF", "TRETSPEF"),
                           generate_numbered_headers("OPERTN_", n = 24)), "&") %>%
           convert_to_NA(generate_numbered_headers("OPERTN_", n = 24), "X999") %>%
           convert_to_NA(generate_numbered_headers("OPERTN_", n = 24), "X998") %>%
           convert_to_NA(generate_numbered_headers("OPERTN_", n = 24), "X997") %>%
           convert_to_NA(c("REFERORG"), "X99998") %>%
           convert_to_NA(c("REFERORG"), "X99999") %>%
           convert_to_NA(c("GPPRAC"), "V81998") %>%
           convert_to_NA(c("GPPRAC"), "V81997") %>%
           convert_to_NA(c("GPPRAC"), "V81999") %>%
           convert_to_NA(c("LSOA11"), "Z99999999") %>%
           convert_to_NA(generate_numbered_headers("DIAG_", n = 20), "R69X") %>%
           convert_to_NA(generate_numbered_headers("DIAG_", n = 20), "R69X6") %>%
           convert_to_NA(generate_numbered_headers("DIAG_", n = 20), "R69X8") %>%
           convert_to_NA(generate_numbered_headers("DIAG_", n = 20), "R69X3") %>%
           convert_vals(c("ADMIMETH"), old_vals = c("2A", "2B", "2C", "2D"), new_vals = c("66", "67", "68", "69")) %>%
           convert_vals(c("DOMPROC"), old_vals = c("-"), new_vals = c("None")) %>%
           convert_vals(c("SPELEND"), old_vals = c("N", "Y"), new_vals = c(0, 1)) %>%
           convert_vals(c("STARTAGE", "APPTAGE", "ARRIVALAGE"), old_vals = 7001:7007, 
                        new_vals = seq(0, 0, length.out = (7007-7000))) %>%
           convert_to_int(c("ADMIMETH", "FIRSTATT"))
  )
}

