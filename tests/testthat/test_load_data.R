library(testthat)
source("src/load_data.R")

expected_headers <- read.csv("tests/dummy_data/example_expected.txt", header = TRUE)

test_that("SQLite database created", {
  db <- set_database("")
  expect_that(file.exists(file.path("HES_db.sqlite")), is_true())
  dbDisconnect(db)
  file.remove("HES_db.sqlite")
})


test_that("README exists and recoverable by collect_filenames()", {
  filepath <- collect_filenames("./")
  expect_that(file.exists(file.path("./README.md")), is_true())
  expect_equal(filepath[grepl("README.md", filepath)], "./README.md")
})


test_that("collect_rows reads in data and only ENCRYPTED_HESID kept", {
  file <- "tests/dummy_data/AA_1.txt"
  data <- collect_rows(file, "ENCRYPTED_HESID", 
                        unlist(fread(file = file, sep="|", header=FALSE, nrows = 1), use.names = FALSE))
  expect_true("ENCRYPTED_HESID" %in% names(data))
  expect_equal(length(names(data)), 1)
})


test_that("read in data chunk with or without coercion", {
  expect_equal(read_HES("tests/dummy_data/AA_1.txt", expected_headers, 3, 1, "temp.txt", TRUE), 
               read_HES("tests/dummy_data/AA_2.txt", expected_headers, 3, 1, "temp.txt", FALSE))
  file.remove("temp.txt")
})


test_that("read_write_HES writes data to database", {
  db <- set_database("")
  read_write_HES(3, "tests/dummy_data/AA_1.txt", expected_headers, 1, db, "AA", "temp.txt", TRUE)
  dbDisconnect(db)
  expect_gt(file.info("HES_db.sqlite")$size, 0)
  file.remove(c("HES_db.sqlite", "temp.txt"))
})


test_that("ingest_HES_file returns IDs", {
  db <- set_database("")
  IDs <- ingest_HES_file("tests/dummy_data/AA_1.txt", "AA", db, expected_headers, "temp.txt", TRUE)
  dbDisconnect(db)
  expect_equal(nrow(IDs), 3)
  expect_equal(IDs[[1]][1], 1234)
  file.remove(c("HES_db.sqlite", "temp.txt"))
})


test_that("ingest_HES_file returns nothing if ENCRYPTED_HESID not present", {
  db <- set_database("")
  IDs <- ingest_HES_file("tests/dummy_data/AA_3.txt", "AA", db, expected_headers, "temp.txt", TRUE)
  dbDisconnect(db)
  expect_null(IDs)
  file.remove(c("HES_db.sqlite", "temp.txt"))
})


test_that("collect_dataset_files only returns search result", {
  filepath <- collect_filenames("./")
  expect_equal((collect_dataset_files(filepath, "README")), "./README.md")
})


test_that("read_HES_dataset read multiple inputs and returns vector of IDs", {
  db <- set_database("")
  data <- read_HES_dataset("AA", collect_filenames("./tests/dummy_data/"),
                           db, expected_headers, "temp.txt", TRUE)
  expect_equal(length(data), 6)
  dbDisconnect(db)
  file.remove(c("HES_db.sqlite", "temp.txt"))
})
