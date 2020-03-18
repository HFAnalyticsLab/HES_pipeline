source("src/load_data.R")
source("src/duplicates.R")
source("src/db_qc.R")


# Main fn for building the database. Will read in, check, and clean the data, then 
# write out to a database.
# Requires a valid directory path to the data, a path to the database, a character 
# vector of dataset codes, an integer vector of the number of rows per chunk for 
# each dataset, a path to a csv of expected headers and a boolean if coercion is 
# required.
# Writes to database as side effect.
# Returns nothing.
build_database <- function(data_path, db, data_set_codes, chunk_sizes, 
                           expected_headers_file, tidy_log, IMD_data, 
                           CCG_data, coerce = FALSE) {
  expected_headers <- read.csv(expected_headers_file, header = TRUE)
  filenames <- collect_filenames(dir_path = data_path)
  if (!is_empty(filenames$ons)) { read_write_ONS(filenames, expected_headers, tidy_log, coerce, database_name = db) }
  IDs <- c(map2(data_set_codes, chunk_sizes,
               ~read_HES_dataset(dataset_code = .x, chunk_size = .y, 
               all_files = filenames$hes, database = db, expected_headers, tidy_log, IMD_data, CCG_data, coerce)))
  log_info("Database built!")
}


# Identifies duplicates and updates database with result
# Requires an S4 MySQLConnection.
# Writes to database as side effect.
# Returns nothing.
modify_database <- function(db, data_set_codes) {
  log_info("Updating database...")
  if("AE" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "AE")) {
      log_info("Flagging duplicate rows in A&E table...")
      AE_group_by <- c("ENCRYPTED_HESID","ARRIVALDATE","PROCODE3","DIAG_01","TREAT_01")
      AE_order_by <- c("ROWQUALITY", "SUBDATE")
      flag_duplicates(db = db, table = "AE", group_by_vars = AE_group_by, order_by_vars = AE_order_by)
    } else {
      log_info("Unable to flag duplicates in A&E dataset, not all required columns present. 
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
      log_info("Unable to update derived variables in A&E dataset, not all required columns present. 
                Check definition of derived variables.")
    }
    
  } else {
    log_info("A&E dataset not updated, does not exist in the database")
  }
  
  if("OP" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "OP")) {
      log_info("Flagging duplicate rows in OP table...")
      OP_group_by <- c("ENCRYPTED_HESID","APPTDATE","PROCODE3","TRETSPEF","MAINSPEF","ATTENDED")
      OP_order_by <- c("ROWQUALITY", "SUBDATE")
      flag_duplicates(db = db, table = "OP", group_by_vars = OP_group_by, order_by_vars = OP_order_by)
    } else {
      log_info("Unable to flag duplicates in OP dataset, not all required columns present. 
                Check definition of duplicates.")
    }
  } else {
    log_info("OP dataset not updated, does not exist in the database")
  }
  if("APC" %in% data_set_codes){
    if("DUPLICATE" %in% dbListFields(db, "APC")) {
      log_info("Flagging duplicate rows in APC table...")
      APC_group_by <- c("ENCRYPTED_HESID","EPISTART","EPIEND","EPIORDER","PROCODE3","ADMIDATE_FILLED","DISDATE","TRANSIT")
      APC_order_by <- c("ROWQUALITY", "SUBDATE", "EPIKEY")
      flag_duplicates(db = db, table = "APC", group_by_vars = APC_group_by, order_by_vars = APC_order_by)
    } else {
      log_info("Unable to flag duplicates in APC dataset, not all required columns present. 
                Check definition of duplicates.")
    }
  } else {
    log_info("APC dataset not updated, does not exist in the database")
  }
  log_info("Updating database complete.")
  
}


# Creates summary stats for each dataset, datafile and variable in the database
# Requires an S4 MySQLConnection, a file path for the output files and date-time. 
# Writes to database and writes csv files as side effect.
# Returns nothing.
quality_control <- function(db, database_path, time) {
   
  data_set_codes <- dbListTables(db)

  dataset_summary_stats <- create_dataset_summary_stats(db, data_set_codes, time)
  dbWriteTable(db, "DATASET_SUMMARY_STATS", dataset_summary_stats, overwrite = TRUE)
  write_csv(dataset_summary_stats, 
            paste0(database_path, "dataset_summary_stats_", Sys.Date(), ".csv"))
  
  file_summary_stats <- create_file_summary_stats(db, data_set_codes, time)
  dbWriteTable(db, "FILE_SUMMARY_STATS", file_summary_stats, overwrite = TRUE)
  write_csv(file_summary_stats, 
            paste0(database_path, "file_summary_stats_", Sys.Date(), ".csv"))
  
  for (d in data_set_codes) {
    var_summary_stats <- create_var_summary_stats(db, d)
    dbWriteTable(db, paste0(d, "_SUMMARY_STATS"), var_summary_stats, overwrite = TRUE)
    write_csv(var_summary_stats, 
              paste0(database_path, d, "_summary_stats_", Sys.Date(), ".csv"))
  }
  
}


# Sets up logging environment when a database build is started.
# Creates pipeline amnd tidying log files.# Creates pipeline amnd tidying log files.
# Requires a path to location of the database.
# Returns tidy log location
start_log <- function(database_path) {
  pipe_log <- generate_log_file(path = database_path, log_type = "pipeline")
  tidy_log <- generate_log_file(path = database_path, log_type = "tidy")
  file.create(pipe_log)
  log_appender(appender_file(pipe_log))
  log_info("Pipeline started...")
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
    names(IMD_15) <- c("LSOA11", "IMD15_RANK", "IMD15_DECILE")
    log_info("Using only 2015 IMD data")
  } else if(!is.null(IMD_19_csv)) {
    IMD_data <- load_IMD(IMD_19_csv)
    names(IMD_15) <- c("LSOA11", "IMD19_RANK", "IMD19_DECILE")
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
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset the path to a csv of 
# expected headers and a boolean if coercion is required.
# Writes to database as side effect. 
# Returns nothing.
initial_run <- function(data_path, database_path, data_set_codes, chunk_sizes, 
                      expected_headers_file, IMD_15_csv, IMD_19_csv, 
                      CCG_xlsx, coerce = FALSE) {
  if(file.exists(paste0(database_path, "HES_db.sqlite"))) {
    already_exists_message <- "Database already exists. Did you mean to use `update = TRUE`?"
    log_info(already_exists_message)
    print(already_exists_message)
  } else {
    run_start <- Sys.time()
    db <- set_database(database_path)
    
    tidy_log <- start_log(database_path)
    
    external_data <- load_additional_data(IMD_15_csv, IMD_19_csv, CCG_xlsx)
    IMD_data <- external_data[1]
    CCG_data <- external_data[2]
    
    build_database(data_path, db, data_set_codes, chunk_sizes, expected_headers_file, tidy_log,
                   IMD_data, CCG_data, coerce)
    modify_database(db, data_set_codes)
    quality_control(db, database_path, run_start)
    dbDisconnect(db)
    log_info("Initial run complete.")
  }
}


# Recovers calendar year from a HES filename.
# Requires a filepath.
# Returns a string.
get_file_year <- function(filepath) {
  substr(str_split(filepath, "_")[[1]][5], 1, 4)
}


# Deletes rows in a database which contain a specific year in their FILENAME variable.
# Requires a table name, an open SQLite database connection and a calendar year as a
# string.
# Updates the database as side effect
# Returns nothing.
remove_data_to_be_updated <- function(table, db, year) {
  dbSendQuery(db, paste0("DELETE FROM", table, " WHERE FILENAME LIKE ", year))
}


# Creates a backup of the existing table within the database.
# Requires a table name and an open SQLite database connection.
# Updates the database as side effect
# Returns nothing.
backup_table <- function(table, db) {
  dbSendQuery(db, paste0("ALTER TABLE ", table, "RENAME TO ", table, "_backup"))
}


# Joins the a new table to the old table.
# Requires a table name and an open SQLite database connection.
# Updates the database as side effect
# Returns nothing.
join_update <- function(data_set_code, db) {
  dbSendQuery(db, paste0("INSERT INTO ", data_set_code, "_backup SELECT * FROM", data_set_code))
  dbSendQuery(db, paste0("DROP TABLE ", data_set_code))
  dbSendQuery(db, paste0("ALTER TABLE ", data_set_code, "_backup RENAME TO ", data_set_code))
}


# Updates the database with new data. Will remove data to be updated.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset the path to a csv of 
# expected headers and a boolean if coercion is required.
# Writes to database as side effect. 
# Returns nothing.
run_update <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000),
                            expected_headers_file, IMD_15_csv = NULL, IMD_19_csv = NULL,
                            CCG_xlsx = NULL, coerce = FALSE) {
  run_start <- Sys.time()
  if(file.exists(paste0(database_path, "HES_db.sqlite"))) {
    doesnt_exists_message <- "Database doesn't exist. Did you mean to use `update = FALSE`?"
    log_info(doesnt_exists_message)
    print(doesnt_exists_message)
  } else {
    db <- set_database(database_path)
    
    tidy_log <- start_log(database_path)
    
    external_data <- load_additional_data(IMD_15_csv, IMD_19_csv, CCG_xlsx)
    IMD_data <- external_data[1]
    CCG_data <- external_data[2]
    
    filenames <- collect_filenames(dir_path = data_path)
    year <- get_file_year(filenames$hes[1])
    walk(data_set_codes, remove_data_to_be_updated, db, year)
    walk(data_set_codes, backup_table, db)
    build_database(data_path, db, data_set_codes, chunk_sizes, expected_headers_file, tidy_log,
                   IMD_data, CCG_data, coerce)
    modify_database(db, data_set_codes)
    map(data_set_codes, join_update, db)
    #spells
    quality_control(db, database_path, run_start)
    dbDisconnect(db)
    log_info("Database update complete.")
  }
}


# Runs the pipeline or updates the database, and logs any errors thrown.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset (default chunk size is 
# 1,000,000 lines per chunk), the path to a csv of expected headers and a boolean if coercion is required.
# Writes to database as side effect.
# Returns nothing.
pipeline <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000), 
                     expected_headers_file, IMD_15_csv = NULL, IMD_19_csv = NULL,
                     CCG_xlsx = NULL, coerce = FALSE, update = FALSE) {
  tryCatch({
    if(update == FALSE) {
      initial_run(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, 
                IMD_15_csv, IMD_19_csv, CCG_xlsx, coerce)
    } else if(update == TRUE) {
      run_update(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, 
                      IMD_15_csv, IMD_19_csv, CCG_xlsx, coerce)
    }
    
  }, error = function(err.msg) {
    log_error(toString(err.msg))
  })
}
