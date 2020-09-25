source("src/load_data.R")
source("src/clean.R")
source("src/derive.R")
source("src/comorbidities.R")
source("src/duplicates.R")
source("src/spells.R")
source("src/db_qc.R")

library(data.table)
library(plyr)
library(tidyverse)
library(DBI)
library(logger)
library(tidylog)
library(readxl)
library(rlang)
library(comorbidity)
library(furrr)
plan(multiprocess)

# Main fn for building the database. Will read in, check, and clean the data, then 
# write out to a database.
# Requires a valid directory path to the data, a path to the database, a character 
# vector of dataset codes, an integer vector of the number of rows per chunk for 
# each dataset, a path to a csv of expected headers, a tidylog location, a dataframe with IMD
# data to be merged, a dataframe with CCG identifiers to be merged. 
# Optional: a boolean if coercion is required, a boolean indicating whether to flag 
# duplicate records, a boolean indicating whether to flag comorbidities.
# Writes to database as side effect.  
# a named list of vectors defining columns used as the basis for rowquality per
# datasets (eg list("AE" = c(cols), ...)), a named list of named lists defining 
# columns to use for deduplication per dataset (eg list("AE" = list("group" = cols1, "order" = cols2), ...)).
# Writes to database as side effect.
# Returns nothing.
build_database <- function(data_path, db, data_set_codes, chunk_sizes, 
                           expected_headers_file, tidy_log, IMD_data, 
                           CCG_data, coerce = FALSE, duplicates = FALSE, comorbidities = FALSE, 
                           rowquality_cols, duplicate_cols) {
  
  expected_headers <- read.csv(expected_headers_file, header = TRUE)
  filenames <- collect_filenames(dir_path = data_path)
  if (!is_empty(filenames$ons)) { read_write_ONS(filenames, expected_headers, tidy_log, coerce, database_name = db) }
  walk2(data_set_codes, chunk_sizes,
        ~read_HES_dataset(dataset_code = .x, chunk_size = .y, 
        all_files = filenames$hes, database = db, expected_headers, tidy_log, IMD_data, 
        CCG_data, coerce, duplicates, comorbidities, rowquality_cols, duplicate_cols))
  log_info("Database built!")
}


# Identifies duplicates and updates database with result
# Requires an S4 MySQLConnection and a named list of named lists defining 
# columns to use for deduplication per dataset (eg list("AE" = list("group" = cols1, "order" = cols2), ...)).
# Writes to database as side effect.
# Returns nothing.
modify_database <-  function(db, duplicate_cols){
  
  data_set_codes <- dbListTables(db)
  
  log_info("Updating database...")
  if("AE" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "AE")) {
      log_info("Flagging duplicate rows in A&E table...")
      flag_duplicates(db = db, table = "AE", group_by_vars = duplicate_cols$AE$group, order_by_vars = duplicate_cols$AE$order)
    } else {
      log_info("Did not flag duplicates in A&E dataset, either because duplicate was set to FALSE or not all required columns present. 
                Check definition of duplicates.")
    }
    
    if(all(c("UNPLANNED", "SEEN", "UNPLANNED_SEEN") %in% dbListFields(db, "AE"))) {
      update_var(db, table = "AE", var = "UNPLANNED", value = TRUE, 
                 condition_query = "WHERE AEATTENDCAT <> 2 AND DUPLICATE = FALSE")
      update_var(db, table = "AE", var = "SEEN", value = TRUE, 
                 condition_query = "WHERE AEATTENDDISP <> 12 AND AEATTENDDISP <> 13 AND DUPLICATE = FALSE")
      update_var(db, table = "AE", var = "UNPLANNED_SEEN", value = TRUE, 
                 condition_query = "WHERE UNPLANNED = 1 AND SEEN = 1")
      log_info("Updating derived variables in the A&E table complete.")
    } else {
      log_info("Did not update derived variables in A&E dataset, either because duplicate was set to FALSE or not all required columns present. 
                Check definition of derived variables.")
    }
    
  } else {
    log_info("A&E dataset not updated, does not exist in the database")
  }
  
  if("OP" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "OP")) {
      log_info("Flagging duplicate rows in OP table...")
      flag_duplicates(db = db, table = "OP", group_by_vars = duplicate_cols$OP$group, order_by_vars = duplicate_cols$OP$order)
    } else {
      log_info("Did not flag duplicates in OP dataset, either because duplicate was set to FALSE or not all required columns present. 
                Check definition of duplicates.")
    }
  } else {
    log_info("OP dataset not updated, does not exist in the database")
  }
  if("APC" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "APC")) {
      log_info("Flagging duplicate rows in APC table...")
      flag_duplicates(db = db, table = "APC", group_by_vars = duplicate_cols$APC$group, order_by_vars = duplicate_cols$APC$order)
    } else {
      log_info("Did not flag duplicates in APC dataset, either because duplicate was set to FALSE or not all required columns present. 
                Check definition of duplicates.")
    }} else {
    log_info("APC dataset not updated, does not exist in the database")
  }
  log_info("Updating database complete.")
}

# Creates inpatient spells and continuous inpatient spells (CIPS)
# Requires an S4 MySQLConnection 
# Writes to database as side effect: adds new columns to APC table, creates APCS table (spells)
# and APCC table (CIPS)
# Returns nothing.

create_spells_cips <- function(db){
  
  if("APC" %in% dbListTables(db) & all(c("ENCRYPTED_HESID", "PROCODE3", "EPISTART", "EPIEND", 
           "EPIORDER", "TRANSIT", "EPIKEY", "ADMIDATE") %in% dbListFields(db, "APC"))) {
    
    spell_grouping_query <- "(PARTITION BY ENCRYPTED_HESID, PROCODE3 ORDER BY EPISTART, EPIEND, EPIORDER, TRANSIT, EPIKEY)"
    cips_grouping_query <- "(PARTITION BY ENCRYPTED_HESID ORDER BY ADMIDATE_FILLED)"
    
    log_info("Deriving spells and spell IDs...")
    derive_spells(db, spell_grouping = spell_grouping_query)

    log_info("Deriving spells and spell IDs complete. Creating spell table...")
    create_inpatient_spells_table(db)
    derive_disdate_missing(db)
    
    log_info("Creating spell table complete. Deriving CIPS and CIPS IDs...")
    derive_cips(db, cips_grouping = cips_grouping_query)

    log_info("Deriving CIPS and CIPS IDs complete. Creating CIPS table...")
    create_cips_table(db)
    log_info("Creating CIPS table complete.")
  } else {
    log_info("Did not create spells table, APC table not present in the database or not all columns 
             needed to create spells present in the APC table.")
  }
  
  
}
  
  

# Creates summary stats for each dataset, datafile and variable in the database
# Requires an S4 MySQLConnection, a file path for the output files and date-time. 
# Writes to database and writes csv files as side effect.
# Returns nothing.
quality_control <- function(db, database_path, time) {
   
  data_set_codes <- dbListTables(db)

  log_info("Creating quality control tables.")
  
  dataset_summary_stats <- create_dataset_summary_stats(db, data_set_codes, time)
  dbWriteTable(db, "DATASET_SUMMARY_STATS", dataset_summary_stats, overwrite = TRUE)
  write_csv(dataset_summary_stats, 
            paste0(database_path, "dataset_summary_stats_", Sys.Date(), ".csv"))
  
  log_info("Summary stats table by dataset created.")
  
  file_summary_stats <- create_file_summary_stats(db, data_set_codes, time)
  dbWriteTable(db, "FILE_SUMMARY_STATS", file_summary_stats, overwrite = TRUE)
  write_csv(file_summary_stats, 
            paste0(database_path, "file_summary_stats_", Sys.Date(), ".csv"))
  
  log_info("Summary stats table by raw file created.")
  
  for (d in data_set_codes) {
    var_summary_stats <- create_var_summary_stats(db, d)
    dbWriteTable(db, paste0(d, "_SUMMARY_STATS"), var_summary_stats, overwrite = TRUE)
    write_csv(var_summary_stats, 
              paste0(database_path, d, "_summary_stats_", Sys.Date(), ".csv"))
  }
  
  log_info("Summary stats tables by variable for each dataset created. Creating quality control tables complete.")
  
}


# Sets up logging environment when a database build is started.
# Creates pipeline and tidying log files.
# Requires a path to location of the database.
# Returns tidy log location
start_log <- function(database_path) {
  pipe_log <- generate_log_file(path = database_path, log_type = "pipeline")
  tidy_log <- generate_log_file(path = database_path, log_type = "tidy")
  file.create(pipe_log)
  log_appender(appender_file(pipe_log))
  log_info("HES PIPELINE LOG")
  log_info("git commit: {system('git log --oneline', intern=TRUE)[1]}")
  log_appender()
  log_tidying <- function(text) {cat(text, file = tidy_log, sep = "\n", append = TRUE)}
  options("tidylog.display" = list(message, log_tidying))
  return(tidy_log)
}


load_additional_data <- function(IMD_15_csv = NULL, IMD_19_csv = NULL, CCG_xlsx = NULL) {
  if(!is.null(IMD_15_csv) & !is.null(IMD_19_csv)) {
    IMD_data <- load_IMDs(IMD_15_csv, IMD_19_csv)
    log_info("Using 2015 & 2019 IMD data")
  } else if(!is.null(IMD_15_csv)) {
    IMD_data <- load_IMD(IMD_15_csv)
    names(IMD_data) <- c("LSOA11", "IMD15_RANK", "IMD15_DECILE")
    log_info("Using only 2015 IMD data")
  } else if(!is.null(IMD_19_csv)) {
    IMD_data <- load_IMD(IMD_19_csv)
    names(IMD_data) <- c("LSOA11", "IMD19_RANK", "IMD19_DECILE")
    log_info("Using only 2019 IMD data")
  } else {
    IMD_data <- NULL
    log_info("No IMD data supplied")
  }
  
  
  if(!is.null(CCG_xlsx)) {
    CCG_data <- load_health_systems_data(CCG_xlsx)
    log_info("Using CCG data")
  } else {
    CCG_data <- NULL
    log_info("No CCG data provided")
  }

  return(list(IMD_data, CCG_data))

}


# Main fn for building an initial database. Will build a database and then update some columns.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes
# and the path to a csv of  expected headers, a named list of vectors defining columns used as the basis for rowquality per
# datasets (eg list("AE" = c(cols), ...)), a named list of named lists defining 
# columns to use for deduplication per dataset (eg list("AE" = list("group" = cols1, "order" = cols2), ...)). 
# Optional: an integer vector of the number of rows per chunk for each dataset (default is 1000000 line per
# chunk), paths to csv and xlsx files containing reference data, a boolean if coercion is required, a 
# boolean indicating whether to flag duplicate records, a boolean indicating whether to flag 
# comorbidities.
# Writes to database as side effect. 
# Returns nothing.
run_initial <- function(data_path, database_path, data_set_codes, chunk_sizes, 
                        expected_headers_file, IMD_15_csv, IMD_19_csv, 
                        CCG_xlsx, coerce = FALSE, duplicates = FALSE, comorbidities = FALSE,
                        rowquality_cols, duplicate_cols) {
  if(file.exists(paste0(database_path, "HES_db.sqlite"))) {
    already_exists_message <- "Database already exists. Did you mean to use `update = TRUE`?"
    log_info(already_exists_message)
    print(already_exists_message)
  } else {
    run_start <- Sys.time()
    db <- set_database(database_path)
    
    tidy_log <- start_log(database_path)
    
    log_info(paste0("Run started to create new database.\nReading all files from folder ", data_path,
                    ".\nReading exptected headers from: ", expected_headers_file, 
                    ".\nCoercing data types: ", coerce, 
                    ".\nFlagging duplicate records: ", duplicates,
                    ".\nFlagging comorbidities: ", comorbidities,
                    ".\nReading additional data from: ", str_c(c(IMD_15_csv, IMD_19_csv, CCG_xlsx), collapse = ", "), ".\n"))
    
    external_data <- load_additional_data(IMD_15_csv, IMD_19_csv, CCG_xlsx)
    IMD_data <- external_data[[1]]
    CCG_data <- external_data[[2]]
    
    build_database(data_path, db, data_set_codes, chunk_sizes, expected_headers_file, tidy_log,
                   IMD_data, CCG_data, coerce, duplicates, comorbidities, rowquality_cols, duplicate_cols)
    modify_database(db, duplicate_cols)
    create_spells_cips(db)
    
    quality_control(db, database_path, time = run_start)
    dbDisconnect(db)
    log_info("Run complete. Database connection closed.")
  }
}


# Recovers calendar year from a HES filename.
# Requires a filepath.
# Returns a string.
get_file_year <- function(filepath) {
  return(str_split(filepath, "_")[[1]] %>% 
    tail(., 1) %>% 
    substr(., 1, 4) %>% 
    str_c("%", ., "%"))
}


# Deletes rows in a database which contain a specific year in their FILENAME variable.
# Requires a table name, an open SQLite database connection and a calendar year as a
# string.
# Updates the database as side effect
# Returns nothing.
remove_data_to_be_updated <- function(table, db, year) {
  dbSendQuery(db, paste0("DELETE FROM ", table, " WHERE FILENAME LIKE '", year, "'"))
}


# Creates a backup of the existing table within the database.
# Requires a table name and an open SQLite database connection.
# Updates the database as side effect
# Returns nothing.
create_backuptable <- function(table, db) {
  
  if(table == "APC"){
    cols_to_keep <- dbListFields(db, "APC")
    cols_to_keep <- cols_to_keep[!cols_to_keep %in% c("NEW_SPELL", "ROWCOUNT", "SPELL_ID")]
    
    dbExecute(db, paste0("CREATE TABLE APC_backup AS 
                          SELECT ", str_c(cols_to_keep, collapse = ", "), " FROM APC"))
    dbRemoveTable(db, "APC")
  }else{
    dbSendQuery(db, paste0("ALTER TABLE ", table, " RENAME TO ", table, "_backup"))
    
  }
}


# Joins the a new table to the old table.
# Requires a table name and an open SQLite database connection.
# Updates the database as side effect
# Returns nothing.
join_update <- function(data_set_code, db) {
  dbSendQuery(db, paste0("INSERT INTO ", data_set_code, "_backup SELECT * FROM ", data_set_code))
  dbSendQuery(db, paste0("DROP TABLE ", data_set_code))
  dbSendQuery(db, paste0("ALTER TABLE ", data_set_code, "_backup RENAME TO ", data_set_code))
}


# Updates the database with new data. Will remove data to be updated.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes
# and the path to a csv of  expected headers, a named list of vectors defining columns used as the basis for rowquality per
# datasets (eg list("AE" = c(cols), ...)), a named list of named lists defining 
# columns to use for deduplication per dataset (eg list("AE" = list("group" = cols1, "order" = cols2), ...)). 
# Optional: an integer vector of the number of rows per chunk for each dataset (default is 1000000 line per
# chunk), paths to csv and xlsx files containing reference data, a boolean if coercion is required, a 
# boolean indicating whether to flag duplicate records, a boolean indicating whether to flag 
# comorbidities.
# Writes to database as side effect. 
# Returns nothing.
run_update <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000),
                       expected_headers_file, IMD_15_csv = NULL, IMD_19_csv = NULL,
                       CCG_xlsx = NULL, coerce = FALSE, duplicates = FALSE,  comorbidities = FALSE,
                       rowquality_cols, duplicate_cols) {
  run_start <- Sys.time()
  if(!file.exists(paste0(database_path, "HES_db.sqlite"))) {
    doesnt_exists_message <- "Database doesn't exist. Did you mean to use `update = FALSE`?"
    log_info(doesnt_exists_message)
    print(doesnt_exists_message)
  } else {
    db <- set_database(database_path)
    
    tidy_log <- start_log(database_path)
    
    filenames <- collect_filenames(dir_path = data_path)
    year <- get_file_year(filenames$hes[1])
    
    walk(data_set_codes, collect_dataset_files, files = filenames)
    
    log_info(paste0("Run started to update existing database.\nDeleting existing records from year: ", gsub("%", "", year), 
                    ".\nReplacing records using files from folder: ", data_path, 
                    ".\nReading exptected headers from: ", expected_headers_file, 
                    ".\nCoercing data types: ", coerce, 
                    ".\nFlagging duplicate records: ", duplicates,
                    ".\nFlagging comorbidities: ", comorbidities,
                    ".\nReading additional data from: ", str_c(c(IMD_15_csv, IMD_19_csv, CCG_xlsx), collapse = ", "), ".\n"))
    
    external_data <- load_additional_data(IMD_15_csv, IMD_19_csv, CCG_xlsx)
    IMD_data <- external_data[[1]]
    CCG_data <- external_data[[2]]
    
    log_info("Deleting old records...")         
    walk(data_set_codes, remove_data_to_be_updated, db, year)
    log_info("Deleting old records complete. Creating backups of remaining records...")
    walk(data_set_codes, create_backuptable, db)
    log_info("Creating backups complete. Processing new data...")
    build_database(data_path, db, data_set_codes, chunk_sizes, expected_headers_file, tidy_log,
                   IMD_data, CCG_data, coerce, duplicates, comorbidities, rowquality_cols, duplicate_cols)
    modify_database(db, duplicate_cols)
    log_info("Merging new data with backup tables...")
    walk(data_set_codes, join_update, db)
    log_info("Merging new data with backup tables complete.")
    create_spells_cips(db)
    quality_control(db, database_path, time = run_start)
    dbDisconnect(db)
    log_info("Database update complete.")
  }
}


# Runs the pipeline or updates the database, and logs any errors thrown.
# Requires a valid directory path to the data, a path to the database and a character vector of dataset 
# codes and the path to a csv of expected headers. 
# Optional arguments: an integer vector of the number of rows per chunk for each dataset (default chunk size is 
# 1,000,000 lines per chunk), paths to csv and xlsx files containing reference data,   
# a boolean if coercion is required, a boolean indicating whether to flag duplicate records and a
# boolean indicating whether to flag comorbidities.
# Writes to database as side effect.
# Returns nothing.
pipeline <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000), 
                     expected_headers_file, IMD_15_csv = NULL, IMD_19_csv = NULL,
                     CCG_xlsx = NULL, coerce = FALSE, duplicates = FALSE,  comorbidities = FALSE,
                     update = FALSE) {
  
  # Columns used to calculate row quality (could be supplied as arguments to pipline 
  # in a future version)
  APC_rowquality_cols <- c(c("ADMIMETH", "ADMISORC", "DISDEST", "DISMETH", "STARTAGE", "MAINSPEF",
                             "TRETSPEF", "SITETRET", "OPERTN_01"),
                           generate_numbered_headers(string = "DIAG_", n = 14))
  AE_rowquality_cols <- c(c("AEARRIVALMODE", "AEATTENDCAT", "AEATTENDDISP", "AEDEPTTYPE", 
                            "ARRIVALAGE", "ARRIVALTIME","CONCLTIME", "DEPTIME", "INITTIME"), 
                          generate_numbered_headers(string = "INVEST_", n = 12), 
                          generate_numbered_headers(string = "TREAT_", n = 12))
  OP_rowquality_cols <- c("APPTAGE", "FIRSTATT", "OUTCOME", "PRIORITY", "REFSOURC", "SERVTYPE",
                          "SITETRET", "STAFFTYP")
  
  # Columns used to flag duplicate rows (could be supplied as arguments to pipline 
  # in a future version)
  AE_group_by <- c("ENCRYPTED_HESID","ARRIVALDATE","PROCODE3","DIAG_01","TREAT_01")
  AE_order_by <- c("ROWQUALITY", "SUBDATE")
  OP_group_by <- c("ENCRYPTED_HESID","APPTDATE","PROCODE3","TRETSPEF","MAINSPEF","ATTENDED")
  OP_order_by <- c("ROWQUALITY", "SUBDATE")
  APC_group_by <- c("ENCRYPTED_HESID","EPISTART","EPIEND","EPIORDER","PROCODE3","ADMIDATE_FILLED","DISDATE","TRANSIT")
  APC_order_by <- c("ROWQUALITY", "SUBDATE", "EPIKEY")
  
  
  tryCatch({
    if(update == FALSE) {
      run_initial(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, 
                IMD_15_csv, IMD_19_csv, CCG_xlsx, coerce, duplicates, comorbidities,
                rowquality_cols = list("AE" = AE_rowquality_cols, "APC" = APC_rowquality_cols, "OP" = OP_rowquality_cols),
                duplicate_cols = list("AE" = list("group" = AE_group_by, "order" = AE_order_by), 
                                      "APC" = list("group" = APC_group_by, "order" = APC_order_by), 
                                      "OP" = list("group" = OP_group_by, "order" = OP_order_by)))
    } else if(update == TRUE) {
      run_update(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, 
                 IMD_15_csv, IMD_19_csv, CCG_xlsx, coerce, duplicates, comorbidities, 
                 rowquality_cols = list("AE" = AE_rowquality_cols, "APC" = APC_rowquality_cols, "OP" = OP_rowquality_cols),
                 duplicate_cols = list("AE" = list("group" = AE_group_by, "order" = AE_order_by), 
                                       "APC" = list("group" = APC_group_by, "order" = APC_order_by), 
                                       "OP" = list("group" = OP_group_by, "order" = OP_order_by)))
    }
    
  }, error = function(err.msg) {
    log_error(toString(err.msg))
  })
}
