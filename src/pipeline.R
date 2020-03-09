source("src/load_data.R")
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
                           expected_headers_file, tidy_log, coerce = FALSE) {
  expected_headers <- read.csv(expected_headers_file, header = TRUE)
  filenames <- collect_filenames(dir_path = data_path)
  if (!is_empty(filenames$ons)) { read_write_ONS(filenames, expected_headers, tidy_log, coerce, database_name = db) }
  IDs <- c(map2(data_set_codes, chunk_sizes,
               ~read_HES_dataset(dataset_code = .x, chunk_size = .y, 
               all_files = filenames$hes, database = db, expected_headers, tidy_log, coerce)))
  log_info("Database built!")
}


# Identifies duplicates and updates database with result
# Requires an S4 MySQLConnection.
# Writes to database as side effect.
# Returns nothing.
update_database <- function(db, data_set_codes) {
  log_info("Updating database...")
  if("AE" %in% data_set_codes){
    # insert duplicate flagging here
    update_var(db, table = "AE", var = "UNPLANNED", value = TRUE, 
               condition_query = "WHERE AEATTENDCAT <> 2 AND DUPLICATE = FALSE")
    update_var(db, table = "AE", var = "SEEN", value = TRUE, 
               condition_query = "WHERE AEATTENDDISP <> 12 AND AEATTENDDISP <> 13 AND DUPLICATE = FALSE")
    update_var(db, table = "AE", var = "UNPLANNED_SEEN", value = TRUE, 
               condition_query = "WHERE UNPLANNED = 1 AND SEEN = 1")
    log_info("Updating A&E table complete.")
  }
  if("OP" %in% data_set_codes){
    # insert duplicate flagging here
    log_info("Updating OP table complete.")
  }
  if("APC" %in% data_set_codes){
    # insert duplicate flagging here
    log_info("Updating APC table complete.")
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
  dbWriteTable(db, "DATASET_SUMMARY_STATS", dataset_summary_stats, append = TRUE)
  write_csv(dataset_summary_stats, 
            paste0(database_path, "dataset_summary_stats_", Sys.Date(), ".csv"))
  
  file_summary_stats <- create_file_summary_stats(db, data_set_codes, time)
  dbWriteTable(db, "FILE_SUMMARY_STATS", file_summary_stats, append = TRUE)
  write_csv(file_summary_stats, 
            paste0(database_path, "file_summary_stats_", Sys.Date(), ".csv"))
  
  for (d in data_set_codes) {
    var_summary_stats <- create_var_summary_stats(db, d)
    dbWriteTable(db, paste0(d, "_SUMMARY_STATS"), var_summary_stats, append = TRUE)
    write_csv(var_summary_stats, 
              paste0(database_path, d, "_summary_stats_", Sys.Date(), ".csv"))
  }
  
}

# Main fn for running the pipeline. Will build a database and the update some columns.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset the path to a csv of 
# expected headers and a boolean if coercion is required.
# Writes to database as side effect. Creates two txt files for logging. 
# Returns nothing.
pipeline_ <- function(data_path, database_path, data_set_codes, chunk_sizes, 
                      expected_headers_file, coerce = FALSE) {
  db <- set_database(database_path)
  
  run_start <- Sys.time()
  pipe_log <- generate_log_file(path = database_path, log_type = "pipeline")
  tidy_log <- generate_log_file(path = database_path, log_type = "tidy")
  file.create(pipe_log)
  log_appender(appender_file(pipe_log))
  log_info("Pipeline started...")
  log_info("git commit: {system('git log --oneline', intern=TRUE)[1]}")
  log_appender()
  
  log_tidying <- function(text) {cat(text, file = tidy_log, sep = "\n", append = TRUE)}
  options("tidylog.display" = list(message, log_tidying))
  
  build_database(data_path, db, data_set_codes, chunk_sizes, expected_headers_file, tidy_log, coerce)
  update_database(db, data_set_codes)
  quality_control(db, database_path, run_start)
  dbDisconnect(db)
  
}


# Runs the pipeline and logs any errors thrown.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset (default chunk size is 
# 1,000,000 lines per chunk), the path to a csv of expected headers and a boolean if coercion is required.
# Writes to database as side effect.
# Returns nothing.
pipeline <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000), 
                     expected_headers_file, coerce = FALSE) {
  tryCatch({
    pipeline_(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, coerce)
  }, error = function(err.msg) {
    log_error(toString(err.msg))
  })
}