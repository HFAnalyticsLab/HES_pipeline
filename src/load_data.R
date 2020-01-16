library(data.table)
library(tidyverse)
library(DBI)
library(logger)
library(tictoc)
source("src/clean.R")


# Chunk size set to 1 million rows
chunk_size <- 1000000 # 1 million


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


# Reads in a single column ("ENCRYPTED_HESID") of a file.
# Requires a valid file path
# Returns a datatable with a single column.
collect_HESID <- function(file_path) {
  return(fread(file=file_path, sep="|", header=TRUE, verbose = TRUE, select = "ENCRYPTED_HESID"))
}


# Filter all possible headers by dataset
# Requires a table of expected headers and a table name as a sting
# Returns a filtered dataset.
filter_headers <- function(expected_headers, table_name) {
  return(expected_headers %>%
           filter(dataset == table_name))
}


# Turn header table into character list
# Requires a table of expected headers and a table name as a sting
# Returns a character list
list_headers <- function(expected_headers, table_name) {
  return(as.character(unlist(expected_headers %>%
                               select("colnames")), use.names = FALSE))
}


# Read in a chunk of a HES file, coercing data types if required.
# Requires a valid raw data file path, a table of expected headers and classes, a chunk size, a 
# row number to skip to and an optional TRUE if coercion is required.
# Returns a dataframe.
read_HES <- function(file_path, header, chunk_size, chunk, coerce) {
  if(missing(coerce)) {
    data <- fread(file = file_path, sep="|", header=FALSE, col.names = list_headers(header)
                  , verbose = TRUE, nrows = chunk_size, skip = chunk)
  } else {
    data <- fread(file = file_path, sep="|", header=FALSE, col.names = list_headers(header)
                  , verbose = TRUE, nrows = chunk_size, skip = chunk, colClasses = as.vector(header$type))
  }
  return(data)
}


# Read in a chunk of a HES file and write to SQLite database.
# Requires a valid raw data file path, vector of expected headers, a chunk size, a row 
# number to skip to, a database object, a string referring to a table name and a vector
# of columns and data classes.
# Writes to database
read_write_HES <- function(file_path, header, chunk_size, chunk, database_name, table_name) {
  data <- read_HES(file_path, header, chunk_size, chunk, class_list)
  return(dbWriteTable(database_name, table_name, data, append = TRUE))
}


# Read in an whole HES file, write to database, and collect IDs
# Reads in the ID column, splits row count into chunks, reads in headers and uses thus information
# to iterate of the file, reading in in chunks and writing directly to the database
# Requires a valid raw data file path, a table name to create if needed, and write to the database,
# the name of a S4 MySQLConnection, a dataframe of expected headers and a vector of columns and data 
# classes.
# Writes to database as side effect.
# Returns a datatable with a single column for IDs. 
ingest_HES_file <- function(file_path, table_name, database_name, expected_headers) {
  tic()
  IDs <- collect_HESID(file_path) 
  line_count <- nrow(IDs)
  chunks <- seq(1, line_count, chunk_size)
  header <- unlist(fread(file = file_path, sep="|", header=FALSE, nrows = 1), use.names = FALSE)
  filtered_header <- filter_headers(expected_headers, table_name)
  for (c in chunks) {
    read_write_HES(file_path, filtered_header, chunk_size, c, database_name, table_name)
  }
  time_taken <- toc()
  log_info("Read in file: {file_path} consisting of {line_count} rows in {time_taken$toc[[1]]} seconds")
  log_info(("{file_path} contains expected headers? {all(header == expected_header)}"))
  return(IDs)
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
# Requires a dataset code character string, a vector of filenames, an S4 MySQLConnection and a table of
# expected headers.
# Writes to database as side effect.
# Returns a vector of IDs
read_HES_dataset <- function(dataset_code, all_files, database, expected_headers) {
  tic()
  files <- collect_dataset_files(all_files, dataset_code)
  IDs <- unlist(map(files, ingest_HES_file, dataset_code, database, expected_headers), 
                use.names = FALSE) 
  time_taken <- toc()
  log_info("Read in dataset: {dataset_code} consisting of {length(IDs)} rows in {time_taken$toc[[1]]} seconds")
  return(IDs)
}


# Generate log file to write to using datetime as a prefix.
# Requires a path to store the log.
# Returns the filepath to the log file.
generate_log_file <- function(path) {
  return(paste0(path, Sys.time() %>% gsub(":", "", .) %>% gsub(" ", "_", .), "_log.txt"))
}

