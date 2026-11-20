test_that("sn_flag handles mixed checkbox encodings", {
  expect_identical(sn_flag(c("1", "true", "X", "0", "false", NA, "")),
                   c(TRUE, TRUE, TRUE, FALSE, FALSE, NA, NA))
  expect_identical(sn_flag(c(NA, ""), na_value = FALSE), c(FALSE, FALSE))
  expect_identical(sn_flag(c(1, 0)), c(TRUE, FALSE))
})

test_that("clean_ein normalizes and drops placeholders", {
  expect_identical(clean_ein(c("01-0215911", "10215911", "EIN-01-0215911")), rep("010215911", 3))
  expect_true(all(is.na(clean_ein(c("000000000", "999999999", "12345", NA, "")))))
  expect_identical(as_ein2(c("010215911", NA)), c("EIN-01-0215911", NA))
})

test_that("parse_irc_section maps common spellings", {
  x <- c("501(c)(3)", "501C3", "501 (C) (3)", "3", "501(c)(6)", "LLC", "Individual",
         "Government", "Corporation", NA, "N/A", "Something odd")
  expect_identical(parse_irc_section(x),
                   c("501c3", "501c3", "501c3", "501c3", "other_exempt", "business", "individual",
                     "government", "business", "unknown", "unknown", "other"))
})

test_that("merger IDs use YEAR-FROM-TO format", {
  expect_identical(merger_id(2020, "01-0215911", "10431680"), "2020-010215911-010431680")
  expect_identical(merger_group_id(2020, "010431680"), "2020-010431680")
  expect_true(is.na(merger_id(2020, "010215911", NA)))
})
