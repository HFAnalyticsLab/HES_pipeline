library(testthat)
source("src/clean.R")


test_that("Apply function to single column", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(1, 2, "baz"))
  expect_equal(is.na(mutate_if_present(data, "y", funs(na_if(., 1)))$y[[1]]), TRUE)
})


test_that("Apply function to multiple columns", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(1, 2, "baz"))
  convert <- mutate_if_present(data, c("y", "x"), funs(na_if(., 1)))
  expect_equal(is.na(convert$y[[1]]), TRUE)
  expect_equal(is.na(convert$x[[3]]), TRUE)
})


test_that("Nothing changes if column not present", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(1, 2, "baz"))
  expect_equal(mutate_if_present(data, "z", funs(na_if(., 1))), data)
})


test_that("Multiple value conversion works across columns", {
  data <- data.frame(x = c("foo", "bar", 1), y = c(1, 2, "baz"))
  expect_equal(convert_vals(data, c("x", "y"), c("foo", 1), c("bar", 2)),
               data.frame(x = c("bar", "bar", 2), y = c(2, 2, "baz")))
})
