library(data.table)

# three donors -> recipient 090000009 (two in 2020, one in 2022), one donor -> 080000008
fl0 <- data.table(
  OBJECTID = paste0("OID-", 1:5),
  EIN2 = c("EIN-01-0000001", "EIN-01-0000002", "EIN-01-0000003", "EIN-01-0000004", "EIN-01-0000005"),
  TAX_YEAR = c(2020L, 2020L, 2022L, 2020L, 2020L),
  HAS_P1 = c(TRUE, TRUE, TRUE, TRUE, TRUE), HAS_P2 = FALSE,
  LEADER_SN = FALSE,
  N_NP_RECIP = c(1L, 2L, 1L, 1L, 5L),
  TOP_SHARE = c(1, 0.8, 1, 1, 0.1),
  TOP_RECIP_EIN = c("090000009", "090000009", "090000009", "080000008", "090000009")
)

test_that("person_key normalizes names", {
  expect_identical(person_key(c("Dr. Jane Q. Smith, PhD", "JANE SMITH", "Smith", NA)),
                   c("JANE SMITH", "JANE SMITH", NA, NA))
})

test_that("leader_overlap matches donor and recipient Part VII in windows", {
  p7 <- data.table(
    EIN2 = c("EIN-01-0000001", "EIN-09-0000009", "EIN-01-0000002", "EIN-09-0000009", "EIN-01-0000004"),
    TAX_YEAR = c("2019", "2021", "2020", "2023", "2020"),
    F9_07_COMP_DTK_NAME_PERS = c("Jane Smith", "JANE Q SMITH", "Bob Jones", "Bob Jones", "Al Roe"))
  out <- leader_overlap(fl0, p7)[order(OBJECTID)]
  expect_identical(out$N_SHARED_P7, c(1L, 0L, 0L, 0L, 0L))
  # 3 and 5: no donor rows in window; 4: no recipient rows
  expect_identical(out$LEADER_P7, c(TRUE, FALSE, NA, NA, NA))
  # donor 2's "Bob Jones" appears at the recipient in 2023, outside t..t+1
  expect_identical(out$N_RECIP_P7[2], 1L)
})

test_that("add_donor_counts counts dominant donors within the window", {
  out <- add_donor_counts(fl0)[order(OBJECTID)]
  expect_identical(out$N_DONORS, c(2L, 2L, 1L, 1L, NA))  # 3 is two years later; 5 is not dominant
  out3 <- add_donor_counts(fl0, window = 2L)[order(OBJECTID)]
  expect_identical(out3$N_DONORS[1:3], c(3L, 3L, 3L))
  # input order must not matter (regression: mask applied after a reordering merge)
  shuffled <- add_donor_counts(fl0[c(5, 3, 1, 4, 2)])[order(OBJECTID)]
  expect_identical(shuffled$N_DONORS, c(2L, 2L, 1L, 1L, NA))
})

test_that("add_filing_history flags final returns and new recipients", {
  header <- data.table(
    EIN2 = c("EIN-01-0000001", "EIN-01-0000002", "EIN-01-0000002", "EIN-09-0000009", "EIN-08-0000008", "EIN-08-0000008"),
    TAX_YEAR = c("2020", "2020", "2021", "2020", "2020", "2021"),
    OBJECTID = c("OID-1", "OID-2", "OID-X", "OID-R9", "OID-R8a", "OID-R8b"),
    F9_00_RETURN_FINAL_X = c("true", "0", "0", "0", "0", "0"),
    F9_00_RETURN_INITIAL_X = c("0", "0", "0", "0", "X", "0"),
    F9_00_YEAR_FORMATION = c("1980", "1990", "1990", "1950", NA, NA))
  out <- add_filing_history(fl0, header)[order(OBJECTID)]
  expect_identical(out$FINAL_RETURN, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(out$DONOR_FILES_LATER[1:2], c(FALSE, TRUE))
  expect_identical(out$R_NEW[c(1, 4)], c(FALSE, TRUE))       # 080000008 filed an initial return in 2020
  expect_identical(out$R_FILES_LATER[4], TRUE)
})

test_that("add_corroboration flags Schedule O text and governing-doc changes", {
  so <- data.table(EIN2 = c("EIN-01-0000001", "EIN-09-0000009", "EIN-01-0000004"),
                   TAX_YEAR = c(2020L, 2020L, 2020L),
                   SO_00_EXPLANATION_TEXT = c("The organization merged into X", "Completed MERGER with Y", "Annual meeting"))
  p6 <- data.table(EIN2 = c("EIN-09-0000009", "EIN-08-0000008"), TAX_YEAR = c(2021L, 2023L),
                   F9_06_GVRN_CHANGE_DOC_X = c("true", "1"))
  out <- add_corroboration(fl0, so, p6)[order(OBJECTID)]
  expect_identical(out$SO_MERGER_TEXT_DONOR, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(out$SO_MERGER_TEXT_RECIP, c(TRUE, TRUE, FALSE, FALSE, TRUE))
  expect_identical(out$GOV_DOC_CHANGE_RECIP, c(TRUE, TRUE, FALSE, FALSE, TRUE))  # 2021 within t..t+1 of 2020
  cl <- classify_transactions(out[, LEADER_P7 := FALSE])[order(OBJECTID)]
  expect_identical(cl$TYPE[1:2], c("merger2", "merger2"))
  expect_identical(cl$BASIS[1:2], c("corroborated", "corroborated"))
})

test_that("add_affiliation combines Schedule R, supporting org, and group exemption", {
  sr <- data.table(EIN2 = "EIN-09-0000009", SR_02_RLTD_ORG_EIN = "010000002")
  sa <- data.table(EIN2 = "EIN-01-0000003", SA_01_PCSTAT_SUPPORT_ORG_X = "X")
  # missing and zero group numbers must not match each other (regression)
  header <- data.table(EIN2 = c("EIN-01-0000004", "EIN-08-0000008", "EIN-01-0000001", "EIN-09-0000009",
                                "EIN-01-0000002", "EIN-01-0000005"),
                       F9_00_GROUP_EXEMPT_NUM = c("1234", "1234", NA, NA, "0000", "0"))
  out <- add_affiliation(fl0, sr, sa, header)[order(OBJECTID)]
  expect_identical(out$AFF_SCHED_R, c(FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(out$AFF_SUPPORT_ORG, c(FALSE, FALSE, TRUE, FALSE, FALSE))
  expect_identical(out$AFF_GROUP, c(FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(out$AFFILIATED, c(FALSE, TRUE, TRUE, TRUE, FALSE))
})

test_that("add_mission_similarity computes Jaccard on mission words", {
  mission <- data.table(EIN2 = c("EIN-01-0000001", "EIN-09-0000009"),
                        F9_03_ORG_MISSION_PURPOSE = c("Provide housing services for families", "Housing services for seniors"))
  out <- add_mission_similarity(fl0, mission)[order(OBJECTID)]
  expect_equal(out$MISSION_SIM[1], 2 / 5)   # {housing, services} / {provide, housing, services, families, seniors}
  expect_true(is.na(out$MISSION_SIM[2]))
})

test_that("merger_features composes everything and feeds the classifier", {
  ev <- list(p7 = data.table(EIN2 = c("EIN-01-0000001", "EIN-09-0000009"), TAX_YEAR = c(2020L, 2020L),
                             F9_07_COMP_DTK_NAME_PERS = c("Ann Lee", "Ann Lee")))
  out <- classify_transactions(merger_features(fl0, ev))[order(OBJECTID)]
  expect_identical(out$TYPE, c("mergerN", "asset_transfer", "asset_transfer", "asset_transfer", "closure"))
})
