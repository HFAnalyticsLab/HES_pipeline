library(data.table)
library(plyr)
library(tidyverse)
library(DBI)
library(logger)
source("src/clean.R")
library(tidylog)
source("src/derive.R")


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


# Returns a list of two lists of files within a directory, corresponding to HES and ONS files
# Requires a valid directory path.
collect_filenames <- function(dir_path) {
  all_files <- list.files(dir_path, full.names = TRUE)
  hes <- all_files[grep("ONS", all_files, invert = TRUE)]
  ons <- all_files[grep("ONS", all_files)]
  return(list("ons" = ons, "hes" = hes))
}


# Reads in a single column ("ENCRYPTED_HESID" or first if not present) of a file.
# Requires a valid file path.
# Returns a datatable with a single column.
collect_rows <- function(file_path, HESID, header) {
  if(HESID %in% names(header)) {
    rows <- fread(file = file_path, sep = "|", header = TRUE, verbose = TRUE, select = "ENCRYPTED_HESID")
  } else {
    rows <- fread(file = file_path, sep = "|", header = TRUE, verbose = TRUE, select = 1)
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
list_headers <- function(expected_headers) {
  return(as.character(unlist(expected_headers %>%
                               dplyr::select("colnames")), use.names = FALSE))
}


# Read in a chunk of a HES file, coercing data types if required.
# Requires a valid raw data file path, a table of expected headers and classes, a chunk size, a 
# row number to skip to, a tidylog location and a boolean if coercion is required.
# Returns a dataframe.
read_HES <- function(file_path, header, chunk_size, chunk, coerce) {
  if(isTRUE(coerce)) {
    data <- fread(file = file_path, sep = "|", header = FALSE, col.names = list_headers(header), 
                  verbose = TRUE, nrows = chunk_size, skip = chunk, na.strings = c("",NULL,"Null","null"),
                  colClasses = as.vector(header$type))
  } else {
    data <- fread(file = file_path, sep = "|", header = FALSE, col.names = list_headers(header), 
                  verbose = TRUE, nrows = chunk_size, skip = chunk, na.strings = c("",NULL,"Null","null"))
  }
  return(data)
}


# Read in ONS and bridge data and merge.
# Requires all ONS file names, a table of expected headers, a tidylog location, and 
# a boolean if coercion is required
# Returns a table of the merged data.
read_ONS <- function(filenames, expected_headers, tidy_log, coerce) {
  ons <- filenames[grep("BF", filenames, invert = TRUE)]
  bridge <- filenames[grep("BF", filenames)]
  ons_header <- fread(file = ons, sep = "|", header = FALSE, nrows = 1) %>%
    mutate_all(toupper) %>%
    unlist(use.names = FALSE)
  bridge_header <- fread(file = bridge, sep = "|", header = FALSE, nrows = 1) %>%
    mutate_all(toupper) %>%
    unlist(use.names = FALSE)
  ons_expected_header <- filter_headers(expected_headers, table_name = "ONS")
  bridge_expected_header <- filter_headers(expected_headers, table_name = "ONS_BF")
  check_headers(file_path = ons, header = ons_header, filtered_header = ons_expected_header)
  check_headers(file_path = bridge, header = bridge_header, filtered_header = bridge_expected_header)
  ons_data <- read_HES(file_path = ons, header = ons_expected_header, chunk_size = 1e+06, 
                       chunk = 1, coerce = coerce)
  bridge_data <- read_HES(file_path = bridge, header = bridge_expected_header, chunk_size = 1e+06, 
                          chunk = 1, coerce = coerce)
  merge_data <- merge(ons_data, bridge_data, by = "RECORD_ID", all.x = TRUE)
}


# Read in ONS data and write to SQLite database.
# Doesn't append to table in database as update files include all previous data.
# Requires all ONS file names, a table of expected headers, a tidylog location, a 
# boolean if coercion is required and a database object.
# Writes to database
read_write_ONS <- function(filenames, expected_headers, tidy_log, coerce, database_name) {
  sink(tidy_log, append = TRUE)
  cat(paste0("Logging cleaning of ONS files.\n"))
  sink()
  start_dataset <- Sys.time()
  ons_files <- filenames$ons
  data <- read_ONS(filenames = ons_files, expected_headers, tidy_log, coerce) %>%
    parse_HES() %>%
    derive_extract(filename = ons_files[grep("BF", ons_files, invert = TRUE)]) %>%
    derive_missing(missing_col = "ENCRYPTED_HESID", new_col = "ENCRYPTED_HESID_MISSING", tidy_log) %>% 
    derive_dod_filled()

  dbWriteTable(conn = database_name, name = "ONS", value = data, overwrite = TRUE)
  finish_dataset <- Sys.time()
  log_info("Read in dataset: ONS in {paste(as.integer(difftime(finish_dataset, start_dataset, units = 'mins')))} minutes")
}


# Read in a chunk of a HES file and write to SQLite database.
# Requires a valid raw data file path, vector of expected headers, a chunk size, a row 
# number to skip to, a database object, a string referring to a table name. a vector
# of columns and data classes, a tidylog location and a boolean if coercion is required.
# Writes to database
read_write_HES <- function(chunk, file_path, header, chunk_size, database_name, table_name,
                           tidy_log, coerce) {
  sink(tidy_log, append = TRUE)
  cat(paste0("Logging cleaning of lines ", chunk, " to ", (chunk + chunk_size), " of ", file_path, "\n"))
  sink()
  start_reading <- Sys.time()
  data <- read_HES(file_path, header, chunk_size, chunk, coerce) %>%
    parse_HES() %>%
    derive_HES(filename = file_path, tidy_log)
  dbWriteTable(conn = database_name, name = table_name, value = data, append = TRUE)
  finish_reading <- Sys.time()
  log_info("{paste(as.integer(chunk_size/1000000))}m lines processed in {paste(as.integer(difftime(finish_reading, start_reading, units = 'secs')))} seconds")
  
}


# Log if all expected headers are present in a file, if false, log missing headers
# Requires a file path as a string, a dataframe of expected headers, and a table of filtered
# headers.
check_headers <- function(file_path, header, filtered_header) {
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
# the number of rows per chunks as an integer, the name of a S4 MySQLConnection, a dataframe of 
# expected headers, a vector of columns and data classes, a tidylog location and a boolean if coercion is required.
# Writes to database as side effect.
# Returns a datatable with a single column for IDs. 
ingest_HES_file <- function(file_path, table_name, chunk_size, database_name, expected_headers, tidy_log, coerce) {
  start_ingest <- Sys.time()
  header <- fread(file = file_path, sep = "|", header = FALSE, nrows = 1) %>%
    mutate_all(toupper) %>%
    unlist(use.names = FALSE)
  filtered_header <- filter_headers(expected_headers, table_name)
  check_headers(file_path, header, filtered_header)
  rows <- collect_rows(file_path, HESID = "ENCRYPTED_HESID", header) 
  line_count <- nrow(rows)
  chunks <- seq(1, line_count, chunk_size)
  walk(chunks, read_write_HES, file_path, header = filtered_header, chunk_size, database_name, table_name, tidy_log, 
       coerce)
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
  } else {
    stop(paste0('No files found for code "', dataset_code, '"'))
  }
}


# Read in a whole HES dataset, write to database, and collect IDs
# Processes entire HES dataset, by reading in all similar files and writing to a table in the 
# database. Collects IDs for entire dataset.
# Requires a dataset code character string, the number of rows per chunks as an integer, a vector of filenames, an S4 MySQLConnection, a table of
# expected headers, a tidylog location and a boolean if coercion is required.
# Writes to database as side effect.
# Returns a vector of IDs
read_HES_dataset <- function(dataset_code, chunk_size, all_files, database, expected_headers, tidy_log, coerce) {
  start_dataset <- Sys.time()
  files <- collect_dataset_files(files  = all_files, dataset_code)
  IDs <- unlist(map(files, ingest_HES_file, table_name = dataset_code, chunk_size, database_name = database, 
                    expected_headers, tidy_log, coerce), 
                use.names = FALSE) 
  finish_dataset <- Sys.time()
  log_info("Read in dataset: {dataset_code} in 
           {paste(as.integer(difftime(finish_dataset, start_dataset, units = 'mins')))} minutes")
  return(IDs)
}

