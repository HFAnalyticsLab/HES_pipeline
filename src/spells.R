
# Sets NEW_SPELL to TRUE where an episode does not belong to the same spell
# as the previous episode.
# Takes an open SQLite database connection.
# Returns nothing, updates the APC table in the database.
derive_new_spell <- function(db, spell_grouping){
  
  cols_to_keep <- dbListFields(db, "APC")
  cols_to_keep <- cols_to_keep[!cols_to_keep %in% c("NEW_SPELL", "ROWCOUNT", "SPELL_ID")]

  dbExecute(db, paste0("CREATE TABLE APC2 AS 
                          SELECT ", str_c(cols_to_keep, collapse = ", "), ", CASE
                          WHEN EPI_VALID IS 0 THEN NULL
                          WHEN ADMIDATE_FILLED = LAG(ADMIDATE_FILLED, 1) OVER ", spell_grouping, " THEN 0
                          WHEN EPISTART = LAG(EPISTART, 1) OVER ", spell_grouping, " THEN 0
                          WHEN LAG(DISMETH, 1) OVER ", spell_grouping, " IN (8,9) AND
                          EPISTART = LAG(EPIEND, 1) OVER ", spell_grouping, " THEN 0
                          ELSE 1
                          END NEW_SPELL 
                         FROM APC"))
  
  dbRemoveTable(db, "APC")
  dbExecute(db, "ALTER TABLE APC2 RENAME TO APC")
  
}

# Create unique spell IDs per patient
# Takes an open SQLite database connection.
# Returns nothing, updates the APC table in the database.
derive_spell_id <- function(db, spell_grouping){
    
  dbExecute(db, paste0("CREATE TABLE APC2 AS
                         SELECT * FROM APC
                         LEFT JOIN
                         (SELECT ENCRYPTED_HESID, NEW_SPELL, EPISTART, EPIEND, ADMIDATE_FILLED, EPIKEY,
                         ROW_NUMBER() OVER (PARTITION BY ENCRYPTED_HESID ORDER BY EPISTART, 
                                                     EPIEND, EPIORDER, TRANSIT, EPIKEY) AS ROWCOUNT
                         FROM APC WHERE NEW_SPELL = 1)
                         USING (ENCRYPTED_HESID, NEW_SPELL, EPISTART, EPIEND, ADMIDATE_FILLED, EPIKEY)"))
  
  dbRemoveTable(db, "APC")
  
  dbExecute(db, paste0("CREATE TABLE APC3 AS
                         SELECT *, CASE
                         WHEN NEW_SPELL IS NULL THEN NULL
                         WHEN NEW_SPELL = 0 THEN LAG(ROWCOUNT, 1) 
                           OVER ", spell_grouping, " 
                         WHEN NEW_SPELL = 1 THEN ROWCOUNT
                         END SPELL_ID 
                         FROM APC2"))
  
  dbRemoveTable(db, "APC2")
  dbExecute(db, "ALTER TABLE APC3 RENAME TO APC")
}


# Recover APC headers pertinent to the start of an episode
# Takes n open SQLite database connection.
# Returns a string of comma separated headers
first_episode_headers <- function(db) {
  headers <- dbListFields(db, "APC") 
  headers <- headers[!headers %in% c("EPIEND", "DISDATE", "DISDEST", "DISMETH", "DISREADYDATE", "EPIKEY",
                                     "EPIDUR", "EPIORDER", "EPISTAT", "MAINSPEF", "SPELBGIN", "SPELDUR",
                                     "SPELEND", "TRETSPEF", "CONSULT_TYPE", "ENCRYPTED_HESID_MISSING",
                                     "PROCODE3_MISSING", "TRANSIT", "ADMIDATE_MISSING", "EPIDUR_CALC",
                                     "EPI_BAD", "EPI_VALID", "NEWSPELL", "ROWCOUNT",
                                     "SUBDATE", "SUSCOREHRG", "SUSHRG", "SUSHRGVERS", "SUSRECID")] 
  return(str_c(headers, collapse = ", "))
} 


# Builds SQL query to recover most variables in the first episode in a spell
# from a list of expected headers in the APC dataset.
# Takes n open SQLite database connection.
# Returns an SQL query as a string
first_episode_query <- function(db) {
  paste("SELECT ", 
        first_episode_headers(db),
        ", EPIKEY AS EPIKEY_ADM, EPI_COUNT
        FROM
        (SELECT *, COUNT() AS EPI_COUNT FROM APC GROUP BY ENCRYPTED_HESID, SPELL_ID)
        WHERE NEW_SPELL = 1")
}


# SQL query to recover variables concerning the last episode in a spell
last_episode_query <- "SELECT ENCRYPTED_HESID, DISDATE, DISDEST, DISMETH, DISREADYDATE, SPELL_ID,
                        EPIKEY AS EPIKEY_DIS, MAX_EPIEND AS EPIEND FROM
                       (SELECT *, MAX(EPIEND) AS MAX_EPIEND FROM APC GROUP BY ENCRYPTED_HESID, SPELL_ID)"


# Joins data from first and last episode in a spell
# to then create the inpatient spells table (APCS).
# Takes an open SQLite database connection and a 
# table of expected headers
# Returns nothing, creates new table in the database.
create_inpatient_spells_table <- function(db) {
  
  if(dbExistsTable(db, "APCS") == TRUE){
    dbRemoveTable(db, "APCS")
  }
  
  dbExecute(db, paste("CREATE TABLE APCS AS 
           SELECT * FROM 
           (", first_episode_query(db), ")
           LEFT JOIN
           (", last_episode_query, ")
           USING (ENCRYPTED_HESID, SPELL_ID)"))
}

# Creates an empty column DISDATE_MISSING in the APCS table and 
# fills it with FALSE (0) where DISDATE is present and with TRUE (1) where
# DISDATE for the spell is missing. 
# Takes an open SQLite database connection.
# Returns nothing, creates new column in the database.
derive_disdate_missing <- function(db){
  
  dbExecute(db, "ALTER TABLE APCS ADD COLUMN DISDATE_MISSING integer")
  
  update_var(db, table = "APCS", var = "DISDATE_MISSING", value = FALSE,
             condition_query = "WHERE DISDATE IS NOT NULL")
  
  updated <- update_var(db, table = "APCS", var = "DISDATE_MISSING", value = TRUE,
             condition_query = "WHERE DISDATE IS NULL")
  
  log_info("Found ", updated, " spells with missing DISDATE.")
}


# Sets NEW_CIPS to TRUE where a spell does not belong to the same continuous inpatient 
# spell (CIPS) as the previous spell
# Takes an open SQLite database connection.
# Returns nothing, updates the APCS table in the database.
derive_new_cips <- function(db, cips_grouping){
  
  cols_to_keep <- dbListFields(db, "APCS")
  cols_to_keep <- cols_to_keep[!cols_to_keep %in% c("NEW_CIPS", "ROWCOUNT", "CIPS_ID")]
  
  
  dbExecute(db, paste0("CREATE TABLE APCS2 AS 
                          SELECT ", str_c(cols_to_keep, collapse = ", "), ", CASE
                          WHEN julianday(EPISTART) - LAG(julianday(EPIEND), 1) OVER ", cips_grouping, " <= 3 
                               AND (LAG(DISDEST, 1) OVER ", cips_grouping, " IN (51, 52, 53) 
                                    OR ADMISORC IN (51, 52, 53)
                                    OR ADMIMETH IN (67, 81)) THEN 0
                          ELSE 1
                          END NEW_CIPS 
                         FROM APCS"))
  
  dbRemoveTable(db, "APCS")
  dbExecute(db, "ALTER TABLE APCS2 RENAME TO APCS")
  
}

# Create unique CIPS IDs per patient
# Takes an open SQLite database connection.
# Returns nothing, updates the APCS table in the database.
derive_cips_id <- function(db, cips_grouping){
  
  dbExecute(db, paste0("CREATE TABLE APCS2 AS
                         SELECT * FROM APCS
                         LEFT JOIN
                         (SELECT ENCRYPTED_HESID, NEW_CIPS, ADMIDATE_FILLED, 
                         ROW_NUMBER() OVER (PARTITION BY ENCRYPTED_HESID ORDER BY ADMIDATE_FILLED) 
                         AS ROWCOUNT
                         FROM APCS WHERE NEW_CIPS = 1)
                         USING (ENCRYPTED_HESID, NEW_CIPS, ADMIDATE_FILLED)"))
  
  dbRemoveTable(db, "APCS")
  
  dbExecute(db, paste0("CREATE TABLE APCS3 AS
                         SELECT *, CASE
                         WHEN NEW_CIPS = 0 THEN LAG(ROWCOUNT, 1) 
                           OVER ", cips_grouping, " 
                         WHEN NEW_CIPS = 1 THEN ROWCOUNT
                         END CIPS_ID 
                         FROM APCS2"))
  
  dbRemoveTable(db, "APCS2")
  dbExecute(db, "ALTER TABLE APCS3 RENAME TO APCS")
}

# Recover APCS headers pertinent to the start of a spell
# Takes n open SQLite database connection.
# Returns a string of comma separated headers
first_spell_headers <- function(db) {
  headers <- dbListFields(db, "APCS") 
  headers <- headers[!headers %in% c("EPIEND", "DISDATE", "DISDEST", "DISMETH", "DISREADYDATE", "EPIKEY",
                                     "EPIDUR", "EPIORDER", "EPISTAT", "MAINSPEF", "SPELBGIN", "SPELDUR",
                                     "SPELEND", "TRETSPEF", "CONSULT_TYPE", "ENCRYPTED_HESID_MISSING",
                                     "PROCODE3_MISSING", "TRANSIT", "ADMIDATE_MISSING", "EPIDUR_CALC",
                                     "EPI_BAD", "EPI_VALID", "NEWSPELL", "ROWCOUNT", "PROCODE3",
                                     "SUBDATE", "SUSCOREHRG", "SUSHRG", "SUSHRGVERS", "SUSRECID")] 
  return(str_c(headers, collapse = ", "))
} 


# Builds SQL query to recover most variables in the first spells in a cips
# from a list of expected headers in the APC dataset.
# Takes n open SQLite database connection.
# Returns an SQL query as a string
first_spell_query <- function(db) {
  paste("SELECT ", 
        first_spell_headers(db),
        ", PROCODE3 AS PROCODE3_FIRST_CIPS, SPELL_COUNT
        FROM
        (SELECT *, COUNT() AS SPELL_COUNT FROM APCS GROUP BY ENCRYPTED_HESID, CIPS_ID)
        WHERE NEW_CIPS = 1")
}


# SQL query to recover variables concerning the last spell in a cips
last_spell_query <- "SELECT ENCRYPTED_HESID, DISDEST, DISMETH, DISREADYDATE, CIPS_ID, 
                        PROCODE3 AS PROCODE3_LAST_CIPS,
                        MAX_DISDATE AS DISDATE FROM
                       (SELECT *, MAX(DISDATE) AS MAX_DISDATE FROM APCS GROUP BY ENCRYPTED_HESID, CIPS_ID)"


# Joins data from first and last episode in a spell
# to then create the inpatient spells table (APCS).
# Takes an open SQLite database connection and a 
# table of expected headers
# Returns nothing, creates new table in the database.
create_cips_table <- function(db) {
  
  if(dbExistsTable(db, "APCC") == TRUE){
    dbRemoveTable(db, "APCC")
  }
  
  dbExecute(db, paste("CREATE TABLE APCC AS 
           SELECT * FROM 
           (", first_spell_query(db), ")
           LEFT JOIN
           (", last_spell_query, ")
           USING (ENCRYPTED_HESID, CIPS_ID)"))
}
