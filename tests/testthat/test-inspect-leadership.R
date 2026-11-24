p7_case <- function(id, donor, recip_pre, recip_post) {
  row <- function(role, t, nm, title = "DIRECTOR", pay = 0)
    data.table::data.table(MERGER_ID = id, ROLE = role, EIN2 = paste(id, role), TIME_FROM_MERGER = t,
                           PERSON_NAME = nm, PERSON_KEY = person_key(nm), TITLE = title, HOURS = 1,
                           COMP_ORG = pay, TRUSTEE = TRUE, OFFICER = FALSE, KEY_EMPLOYEE = FALSE,
                           HIGH_COMP = FALSE, FORMER = FALSE)
  rbind(data.table::rbindlist(lapply(donor, function(n) row("donor", 0L, n))),
        data.table::rbindlist(lapply(recip_pre, function(n) row("recipient", -1L, n))),
        data.table::rbindlist(lapply(recip_post, function(n) row("recipient", 1L, n))))
}

test_that("leadership_inspection groups, flags, and samples by retention", {
  p7 <- rbind(
    p7_case("C1", c("ANN LEE", "BOB RAY"), "CAL DOE", c("CAL DOE", "DAN FOX")),               # none
    p7_case("C2", c("ANN LEE", "BOB RAY", "EVE KIM"), "CAL DOE", c("CAL DOE", "ANN LEE")),     # some
    p7_case("C3", c("ANN LEE", "BOB RAY"), "CAL DOE", c("ANN LEE", "BOB RAY", "CAL DOE")))     # most
  # one person whose title and pay change between years
  p7 <- rbind(p7, data.table::data.table(MERGER_ID = "C3", ROLE = "donor", EIN2 = "C3 donor", TIME_FROM_MERGER = -1L,
                                         PERSON_NAME = "Ann Lee", PERSON_KEY = "ANN LEE", TITLE = "CHAIR", HOURS = 5,
                                         COMP_ORG = 1000, TRUSTEE = TRUE, OFFICER = TRUE, KEY_EMPLOYEE = FALSE,
                                         HIGH_COMP = FALSE, FORMER = FALSE))
  x <- leadership_inspection(list(part7 = p7), n = 3)
  expect_setequal(unique(x$RETENTION), c("none", "some", "most"))
  expect_setequal(unique(x$CASE), c("ORG A", "ORG B", "MERGED"))
  ann <- x[MERGER_ID == "C3" & CASE == "ORG A" & PERSON_KEY == "ANN LEE"]
  expect_equal(nrow(ann), 1L)
  expect_equal(ann$TITLE, "CHAIR {t=-1};; DIRECTOR {t=0}")
  expect_equal(ann$NAME, "Ann Lee {t=-1};; ANN LEE {t=0}")
  expect_true(ann$RETAINED_FROM_A)
  expect_false(x[MERGER_ID == "C1" & CASE == "ORG A" & PERSON_KEY == "ANN LEE", RETAINED_FROM_A])
  expect_equal(x[MERGER_ID == "C2", unique(SHARE_A_RETAINED)], round(1 / 3, 3))
  f <- tempfile(fileext = ".csv")
  leadership_inspection(list(part7 = p7), n = 3, file = f)
  expect_true(file.exists(f))
})
