

# Updates a variable in a table of the SQL database according to conditions
# Requires access to an open HES SQLite database connection, a table name 
# and variable name to update and a SQL query as a string.
# Side effect of updating the database.
# Doesn't return anything.
update_var <- function(db, table, var, value, condition_query) {
  dbExecute(db, paste0("UPDATE ", table, " SET ", var, " = ", value, " ", condition_query))
}


# Flags duplicates by counting how many rows have the same information in a defined 
# set of columns (group_by_vars). In addition, if present, test if ARRIVALTIME is within < 1hr.
# Reads ARRIVALTIME as an integer so a difference of 100 translates to 1hr,
# e.g. 1600 - 1548 = 52 ~ 12mins difference.
# Creates additional columns containing the count of rows with the same values 
# and a rank indicating the quality of each row based on order_by_vars.
# Where duplicate count is more than one, flags the lower quality row as a duplicate.
# Requires access to an open HES SQLite database connection, a table name to update,
# a list of variables to group by and another list of variables to order by.
# Side effect of updating the database.
# Doesn't return anything.
flag_duplicates <- function(db, table, group_by_vars, order_by_vars) {
  order_by_vars <- str_c(order_by_vars, ' DESC', collapse = ', ')
  group_by_vars <- paste0(group_by_vars, collapse = ",")
  new_table <- paste0(table, "_temp")
  time_diff <- if(("ARRIVALTIME" %in% dbListFields(db, table)) == TRUE) {
    c(",(MAX(CAST(ARRIVALTIME as integer)) - MIN(CAST(ARRIVALTIME as integer))) as TIME_DIFF",
      "AND TIME_DIFF < 100")
  } else {
    c("", "")
  }
  dbExecute(db, paste0("CREATE TABLE ", new_table, " AS 
                         SELECT *, ROW_NUMBER() 
                         OVER
                         (PARTITION BY ", group_by_vars, 
                         " ORDER BY ", order_by_vars, ") AS DUPLICATE_QUALITYRANK FROM ",
                         table,
                         " LEFT JOIN 
                         (SELECT ", group_by_vars, ",COUNT() AS DUPLICATE_COUNT", 
                         time_diff[1], 
                         " FROM ", table,
                         " GROUP BY ", group_by_vars, ")
                         USING (", group_by_vars, ")"))
  updated <- update_var(db, table = new_table, var = "DUPLICATE", value = TRUE,
                       condition_query = paste0("WHERE DUPLICATE_COUNT > 1 AND DUPLICATE_QUALITYRANK > 1 ", 
                                                time_diff[2]))
  log_info("Found ", updated, " duplicates in A&E dataset")
  dbExecute(db, paste0("DROP TABLE ", table))
  dbExecute(db, paste0("ALTER TABLE ", new_table, " RENAME TO ", table))
}

