library(testthat)
source("src/load_data.R")


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


test_that("collect_HESID reads in data and only ENCRYPTED_HESID kept", {
  data <- collect_HESID("tests/dummy_data/IDs.txt")
  expect_true("ENCRYPTED_HESID" %in% names(data))
  expect_equal(length(names(data)), 1)
})


test_that("read_write_HES writes data to database", {
  db <- set_database("")
  read_write_HES("tests/dummy_data/IDs.txt", c("ENCRYPTED_HESID", "OTHER"), 4, 1, db, "foo")
  dbDisconnect(db)
  expect_gt(file.info("HES_db.sqlite")$size, 0)
  file.remove("HES_db.sqlite")
})


test_that("ingest_HES_file returns IDs", {
  db <- set_database("")
  expected_headers <- data.frame("colnames" = c("ENCRYPTED_HESID", "OTHER"), "dataset" = c("foo", "foo"))
  IDs <- ingest_HES_file("tests/dummy_data/IDs.txt", "foo", db, expected_headers)
  dbDisconnect(db)
  expect_equal(nrow(IDs), 3)
  expect_equal(IDs[[1]][1], 1234)
  file.remove("HES_db.sqlite")
})


test_that("collect_dataset_files only returns search result", {
  filepath <- collect_filenames("./")
  expect_equal((collect_dataset_files(filepath, "README")), "./README.md")
})


test_that("read_HES_dataset read multiple inputs and returns vector of IDs", {
  db <- set_database("")
  expected_headers <- data.frame("colnames" = c("ENCRYPTED_HESID", "OTHER"), "dataset" = c("foo", "foo"))
  data <- read_HES_dataset("ID", collect_dataset_files(collect_filenames("./tests/dummy_data/"), "ID"), 
                           db, expected_headers)
  expect_equal(length(data), 6)
  dbDisconnect(db)
  file.remove("HES_db.sqlite")
})
