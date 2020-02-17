source("src/load_data.R")


# Main fn for running the pipeline. Will read in, check, and clean the data, then writing out to 
# the database.
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an integer vector of the number of rows per chunk for each dataset, the path to a csv of expected headers 
# and a boolean if coercion is required.
# Writes to database as side effect.
# Returns nothing.
pipeline_ <- function(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, coerce = FALSE) {
  pipe_log <- generate_log_file(database_path, "pipeline")
  tidy_log <- generate_log_file(database_path, "tidy")
  file.create(pipe_log)
  log_appender(appender_file(pipe_log))
  log_info("Pipeline started...")
  log_info("git commit: {system('git log --oneline', intern=TRUE)[1]}")
  log_appender()
  expected_headers <- read.csv(expected_headers_file, header = TRUE)
  filenames <- collect_filenames(data_path)
  db <- set_database(database_path)
  if (!is_empty(filenames$ons)) { read_write_ONS(filenames, expected_headers, tidy_log, coerce, db) }
  log_tidying <- function(text) {cat(text, file = tidy_log, sep = "\n", append = TRUE)}
  options("tidylog.display" = list(message, log_tidying))
  IDs <- c(map2(data_set_codes, chunk_sizes,
               ~read_HES_dataset(dataset_code = .x, chunk_size = .y, 
               filenames$hes, db, expected_headers, tidy_log, coerce)))
  dbDisconnect(db)
  log_info("Database built!")
}

# Runs the pipeline and logs any errors thrown
# Requires a valid directory path to the data, a path to the database, a character vector of dataset codes, 
# an optional integer vector of the number of rows per chunk for each dataset (default chunk size is 
# 1,000,000 lines per chunk), the path to a csv of expected headers and a boolean if coercion is required.
# Writes to database as side effect.
# Returns nothing.
pipeline <- function(data_path, database_path, data_set_codes, chunk_sizes = c(1000000), expected_headers_file, coerce) {
  tryCatch({
    pipeline_(data_path, database_path, data_set_codes, chunk_sizes, expected_headers_file, coerce)
  }, error = function(err.msg) {
    log_error(toString(err.msg))
  })
}