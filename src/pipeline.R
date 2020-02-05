source("src/load_data.R")


# Main fn for running the pipeline. Will read in, check, and clean the data, then writing out to 
# the database.
# Requires a valid directory path to the data, a path to the database, the path to a csv of 
# expected headers and a boolean if coercion is required.
# Writes to database as side effect.
# Returns nothing (for the moment)
pipeline <- function(data_path, database_path, data_set_codes, expected_headers_file, coerce) {
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
  log_tidying <- function(text) {cat(text, file = tidy_log, sep = "\n", append = TRUE)}
  options("tidylog.display" = list(message, log_tidying))
  IDs <- c(map(data_set_codes, read_HES_dataset, filenames, db, expected_headers, tidy_log, coerce))
  dbDisconnect(db)
}

