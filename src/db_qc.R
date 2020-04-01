

# Creates a datatable of summary stats for each dataset 
# processed by the pipeline.
# Requires an SQLite database connection, a vector of
# data set codes and date-time.
# Returns a datatable
create_dataset_summary_stats <- function(db, data_set_codes, time) {
  datasets <- data.frame()
  
  for (t in data_set_codes) {
    if ("DUPLICATE" %in% dbListFields(db, t)) { 
      row <- dbGetQuery(db, paste0("SELECT COUNT() AS NO_RECORDS, SUM(DUPLICATE) 
      AS NO_DUPLICATES, 100*(SUM(DUPLICATE)/COUNT()) AS PCT_DUPLICATES FROM ", t))
    } else {
      row <- dbGetQuery(db, paste0("SELECT COUNT() AS NO_RECORDS FROM ", t))
      row$NO_DUPLICATES <- NA
      row$PCT_DUPLICATES <- NA    
      }
    datasets <- rbind(datasets,row)
  }
  
  datasets$DATASET <- data_set_codes
  datasets$RUNTIME <- as.character(time)
  return(datasets)
}


# Creates a datatable of summary stats for each file 
# processed by the pipeline.
# Requires an SQLite database connection, a vector of
# data set codes = and date-time.
# Returns a datatable
create_file_summary_stats <- function(db, data_set_codes, time) {
  combined_table <- data.frame()
  
  for (t in data_set_codes) {
    if ("DUPLICATE" %in% dbListFields(db, t)) {
      table <- dbGetQuery(db, paste0("SELECT COUNT() AS NO_RECORDS, SUM(DUPLICATE) 
      AS NO_DUPLICATES, 100*(SUM(DUPLICATE)/COUNT()) AS PCT_DUPLICATES, FILENAME FROM ", t, " GROUP BY FILENAME"))
    } else {
      table <- dbGetQuery(db, paste0("SELECT COUNT() AS NO_RECORDS, FILENAME FROM ", t, " GROUP BY FILENAME"))
      table$NO_DUPLICATES <- NA
      table$PCT_DUPLICATES <- NA     
    }
    combined_table <- rbind(combined_table,table)
  }
  
  combined_table$RUNTIME <- as.character(time)
  return(combined_table)
}


# SQL query to count number of missing values in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_is_null_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT COUNT() AS NO_MISSING FROM ", table, " WHERE ", var, " IS NULL"))
}

# SQL query to calculate the percentage of missing values in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_pct_null_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT 100*COUNT() / (SELECT COUNT() FROM ", 
  table, " WHERE ", var, " IS NULL) AS PCT_MISSING FROM ", table))
}

# SQL query to get the maximum value in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_max_val_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT MAX(", var, ") AS MAX FROM ", table))
}


# SQL query to get the minimum value in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_min_val_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT MIN(", var, ") AS MIN FROM ", table))
}


# SQL query to get the mean value in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_mean_val_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT AVG(", var, ") AS MEAN FROM ", table))
}


# SQL query to get a sum of the unique values in a variable.
# Requires an SQLite database connection, a table name
# and a variable name.
# Returns a datatable of the SQL query result.
variable_count_unique_val_query <- function(db, table, var) {
  dbGetQuery(db, paste0("SELECT COUNT(DISTINCT ", var, ") AS NO_UNIQUE_VALS FROM ", table))
}


# Creates a datatable of summary stats for each variable 
# within each dataset processed by the pipeline.
# Requires an SQLite database connection and a vector of
# data set codes
# Returns a datatable
create_var_summary_stats <- function(db, dataset) {
  var_summary_stats <- data.frame()
  
  for (f in dbListFields(db, dataset)) {
    missing <- variable_is_null_query(db, dataset, f)
    missing_pct <- variable_pct_null_query(db, dataset, f)
    maximum <- variable_max_val_query(db, dataset, f)
    minimum <- variable_min_val_query(db, dataset, f)
    mean <- variable_mean_val_query(db, dataset, f)
    uniq <- variable_count_unique_val_query(db, dataset, f)
    var_summary_stats <- rbind(var_summary_stats, cbind(missing, missing_pct, maximum, minimum, mean, uniq))
  }
  
  var_summary_stats$VARIABLE <- dbListFields(db, dataset)
  var_summary_stats <- convert_to_int(var_summary_stats, c("MAX", "MEAN", "MIN"))
  return(var_summary_stats)
}

