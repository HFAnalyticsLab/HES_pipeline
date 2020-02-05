library(data.table)
library(tidyverse)
library(DBI)
library(logger)
source("src/clean.R")
library(tidylog)
source("src/derive.R")


# Chunk size set to 1 million rows
chunk_size <- 1000000 # 1 million


# Generate log file to write to using datetime as a prefix.
# Requires a path to store the log.
# Returns the filepath to the log file.
generate_log_file <- function(path, log_type) {
  return(paste0(path, Sys.time() %>% gsub(":", "", .) %>% gsub(" ", "_", .), "_", log_type, "_", "log.txt"))
}


# Initialises a location for the SQLite database.
# If the database does not already exist also creates it.
# Requires a valid path to the database location.
# Returns a S4 MySQLConnection
set_database <- function(database_path) {
  return(dbConnect(RSQLite::SQLite(), paste0(database_path, "HES_db.sqlite")))
}


# Returns a list of files within a directory.
# Requires a valid directory path.
collect_filenames <- function(dir_path) {
  return(list.files(dir_path, full.names = TRUE))
}


# Reads in a single column ("ENCRYPTED_HESID" or first if not present) of a file.
# Requires a valid file path.
# Returns a datatable with a single column.
collect_rows <- function(file_path, HESID, header) {
  if(HESID %in% names(header)) {
    rows <- fread(file=file_path, sep="|", header=TRUE, verbose = TRUE, select = "ENCRYPTED_HESID")
  } else {
    rows <- fread(file=file_path, sep="|", header=TRUE, verbose = TRUE, select = 1)
  }
  return(rows)
}


# Filter all possible headers by dataset
# Requires a table of expected headers and a table name as a string
# Returns a filtered dataset.
filter_headers <- function(expected_headers, table_name) {
  return(expected_headers %>%
           dplyr::filter(dataset == table_name))
}


# Turn header table into character list
# Requires a table of expected headers and a table name as a string
# Returns a character list
list_headers <- function(expected_headers, table_name) {
  return(as.character(unlist(expected_headers %>%
                               dplyr::select("colnames")), use.names = FALSE))
}


# Read in a chunk of a HES file, coercing data types if required.
# Requires a valid raw data file path, a table of expected headers and classes, a chunk size, a 
# row number to skip to, a tidylog location and a boolean if coercion is required.
# Returns a dataframe.
read_HES <- function(file_path, header, chunk_size, chunk, tidy_log, coerce) {
  start_reading <- Sys.time()
  if(isTRUE(coerce)) {
    data <- fread(file = file_path, sep="|", header=FALSE, col.names = list_headers(header)
                  , verbose = TRUE, nrows = chunk_size, skip = chunk, na.strings = c("",NULL,"Null","null"),
                  colClasses = as.vector(header$type))
  } else {
    data <- fread(file = file_path, sep="|", header=FALSE, col.names = list_headers(header)
                  , verbose = TRUE, nrows = chunk_size, skip = chunk, na.strings = c("",NULL,"Null","null"))
  }
  finish_reading <- Sys.time()
  log_info("1m lines processed in {paste(as.integer(difftime(finish_reading, start_reading, units = 'secs')))} seconds")
  sink(tidy_log, append = TRUE)
  cat(paste0("Logging cleaning of lines ", chunk, " to ", (chunk + chunk_size), " of ", file_path, "\n"))
  sink()
  return(data)
}


# Read in a chunk of a HES file and write to SQLite database.
# Requires a valid raw data file path, vector of expected headers, a chunk size, a row 
# number to skip to, a database object, a string referring to a table name. a vector
# of columns and data classes, a tidylog location and a boolean if coercion is required.
# Writes to database
read_write_HES <- function(chunk, file_path, header, chunk_size, database_name, table_name,
                           tidy_log, coerce) {
  data <- read_HES(file_path, header, chunk_size, chunk, tidy_log, coerce) %>%
    parse_HES() %>%
    derive_HES(file_path)
  dbWriteTable(database_name, table_name, data, append = TRUE)
}


# Log if all expected headers are present in a file, if false, log missing headers
# Requires a file path as a string, a dataframe of expected headers, a table of filtered
# header and a table name to filter on.
check_headers <- function(file_path, header, filtered_header, table_name) {
  header_list <- list_headers(filtered_header)
  check_headers <- all(header == header_list)
  log_info("{file_path} contains expected headers? {check_headers}")
  if(check_headers == FALSE) {
    log_info("{setdiff(header, header_list)} header(s) are missing")
  }
}


# Read in an whole HES file, write to database, and collect IDs
# Reads in the ID column, splits row count into chunks, reads in headers and uses thus information
# to iterate of the file, reading in in chunks and writing directly to the database
# Requires a valid raw data file path, a table name to create if needed, and write to the database,
# the name of a S4 MySQLConnection, a dataframe of expected headers, a vector of columns and data 
# classes, a tidylog location and a boolean if coercion is required.
# Writes to database as side effect.
# Returns a datatable with a single column for IDs. 
ingest_HES_file <- function(file_path, table_name, database_name, expected_headers, tidy_log, coerce) {
  start_ingest <- Sys.time()
  header <- unlist(fread(file = file_path, sep="|", header=FALSE, nrows = 1), use.names = FALSE)
  filtered_header <- filter_headers(expected_headers, table_name)
  check_headers(file_path, header, filtered_header, table_name)
  rows <- collect_rows(file_path, "ENCRYPTED_HESID", header) 
  line_count <- nrow(rows)
  chunks <- seq(1, line_count, chunk_size)
  map(chunks, read_write_HES, file_path, filtered_header, chunk_size, database_name, table_name, tidy_log, coerce)
  finish_ingest <- Sys.time()
  log_info("Read in file: {file_path} consisting of {line_count} rows in 
           {paste(as.integer(difftime(finish_ingest, start_ingest, units = 'mins')))} minutes")
  if("ENCRYPTED_HESID" %in% header) {
    return(rows)
  }
}


# Filter filenames by dataset.
# Requires a vector of filenames and a dataset code character string to filter by.
# Returns vector of filenames for a specific dataset.
collect_dataset_files <- function(files, dataset_code) {
  if (!is_empty(files[grepl(dataset_code, files)])) {
    return(files[grepl(dataset_code, files)])
  }
}


# Read in a whole HES dataset, write to database, and collect IDs
# Processes entire HES dataset, by reading in all similar files and writing to a table in the 
# database. Collects IDs for entire dataset.
# Requires a dataset code character string, a vector of filenames, an S4 MySQLConnection, a table of
# expected headers, a tidylog location and a boolean if coercion is required.
# Writes to database as side effect.
# Returns a vector of IDs
read_HES_dataset <- function(dataset_code, all_files, database, expected_headers, tidy_log, coerce) {
  start_dataset <- Sys.time()
  files <- collect_dataset_files(all_files, dataset_code)
  IDs <- unlist(map(files, ingest_HES_file, dataset_code, database, expected_headers, tidy_log, coerce), 
                use.names = FALSE) 
  finish_dataset <- Sys.time()
  log_info("Read in dataset: {dataset_code} in 
           {paste(as.integer(difftime(finish_dataset, start_dataset, units = 'mins')))} minutes")
  return(IDs)
}

