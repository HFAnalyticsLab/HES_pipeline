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


test_that("Add ROWQUALITY column if provided column(s) present", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(NA, 2, "baz"))
  expect_1 <- derive_row_quality(data, "x")
  expect_equal(expect_1$ROWQUALITY, c(0,0,0))
  expect_2 <- derive_row_quality(data, c("x","y"))
  expect_equal(expect_2$ROWQUALITY, c(1,0,0))
})


test_that("ROWQUALITY = 1 when 1 NA present", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(NA, 2, "baz"))
  expect <- derive_row_quality(data, c("x","y"))
  expect_equal(expect$ROWQUALITY[1], 1)
})


test_that("ROWQUALITY not derived when columns not present", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(NA, 2, "baz"))
  expect <- derive_row_quality(data, "z")
  expect_equal(data, expect)
})

