skip_if_not_installed("peopleparser")

test_that("canonical keys merge nicknames and titles, simple keys do not", {
  x <- c("Robert Smith", "BOB SMITH", "Dr. Robert J. Smith PhD", "Joe Walker", "JOSEPH WALKER",
         "RUSSELL DEPP", "RAYMOND DEPP", NA, "")
  k <- name_key(x)
  expect_equal(length(unique(k[1:3])), 1L)
  expect_equal(k[4], k[5])
  expect_false(k[6] == k[7])
  expect_true(all(is.na(k[8:9])))
  s <- name_key(x[1:3], "simple")
  expect_false(s[1] == s[2])
  kt <- name_keys(x)
  expect_true(all(c("PERSON_NAME", "FIRST_NAME", "LAST_NAME", "FIRST_CANONICAL", "CANONICAL_RULE",
                    "PERSON_KEY") %in% names(kt)))
  expect_equal(nrow(kt), 7L)   # distinct, non-empty names
})

test_that("the session cache returns the same keys and can be saved and preloaded", {
  x <- c("Mike Lieb", "MICHAEL Lieb")
  a <- name_key(x)
  expect_equal(a[1], a[2])
  saved <- name_keys_cached()
  expect_true(all(x %in% saved$PERSON_NAME))
  expect_equal(name_keys_preload(saved[PERSON_NAME %in% x]), 2L)
  expect_identical(name_key(x), a)
})

test_that("name_match_basis labels why two roster names matched", {
  p <- data.table::data.table(
    MERGER_ID = "M1",
    ROLE = rep(c("donor", "recipient"), 4),
    PERSON_NAME = c("ANN LEE", "ANN LEE",                 # exact
                    "BOB RAY", "ROBERT RAY",              # nickname
                    "STEVEN COLE", "STEPHEN COLE",        # spelling
                    "ZED FOX", "ZEDD FOX"))               # not a known pair
  nk <- name_keys(p$PERSON_NAME)
  p <- merge(p, nk[, list(PERSON_NAME, PERSON_KEY, FIRST_NAME)], by = "PERSON_NAME")
  # force the last pair onto one key to test the fallback label
  p[PERSON_NAME %in% c("ZED FOX", "ZEDD FOX"), PERSON_KEY := "ZED FOX"]
  b <- name_match_basis(p)
  lab <- stats::setNames(b$MATCH_BASIS, b$PERSON_KEY)
  expect_equal(unname(lab[nk[PERSON_NAME == "ANN LEE", PERSON_KEY]]), "exact")
  expect_equal(unname(lab[nk[PERSON_NAME == "BOB RAY", PERSON_KEY]]), "nickname")
  expect_equal(unname(lab[nk[PERSON_NAME == "STEVEN COLE", PERSON_KEY]]), "spelling")
  expect_equal(unname(lab["ZED FOX"]), "indirect")
  expect_true(b[PERSON_KEY == "ZED FOX", REVIEW])
  expect_false(any(b[MATCH_BASIS %in% c("exact", "nickname", "spelling"), REVIEW]))
})

test_that("merger_rules carries the name key choice", {
  expect_equal(merger_rules()$name_key, "canonical")
  expect_equal(merger_rules(name_key = "simple")$name_key, "simple")
})

test_that("in-process and cluster parsing give the same keys, and peopleparser is detached after", {
  x <- c("Robert Smith", "BOB SMITH", "Sister Maureen Reardon", "JOSEPH WALKER", "Joe Walker",
         "MRS PAT JONES", "Kathy Lee", "Dr. Jane Q. Smith, PhD")
  was <- "package:peopleparser" %in% search()
  a <- npmerger:::.parse_people(x, peopleparser::prx, workers = 1L)
  expect_equal(nrow(a), length(x))
  expect_identical("package:peopleparser" %in% search(), was)
  skip_on_cran()
  big <- rep(x, length.out = 2400)   # above the size that starts a cluster
  b <- npmerger:::.parse_people(big, peopleparser::prx, workers = 2L)
  expect_identical(b$first_name_canonical[seq_along(x)], a$first_name_canonical)
  expect_identical(b$last_name[seq_along(x)], a$last_name)
})
