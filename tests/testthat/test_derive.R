library(testthat)
source("src/derive.R")


test_that("If \"missing_col\" is missing, do nothing", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(1, 2, "baz"))
  expect_equal(data, derive_missing(data, "z", "a"))
})

test_that("Add column if \"missing_col\" has NAs", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(NA, 2, "baz"))
  expect <- data.frame(x = c("foo", "bar", 1), y = c(NA, 2, "baz"), z = c(TRUE, FALSE, FALSE))
  expect_equal(expect, derive_missing(data, "y", "z"))
})
