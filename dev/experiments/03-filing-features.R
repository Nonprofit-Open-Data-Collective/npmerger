suppressMessages(library(data.table)); S <- Sys.getenv("S"); sn <- readRDS(file.path(S,"sn.rds")); list2env(sn, environment())
flag <- function(x) { x <- tolower(trimws(x)); fifelse(x %in% c("1","true","x","yes"), TRUE, fifelse(x %in% c("0","false","no"), FALSE, NA)) }
irc_type <- function(x) { u <- toupper(gsub("[^A-Za-z0-9]", "", x))
  fcase(is.na(u) | u %in% c("","NA","NONE","0"), "unknown",
        grepl("^(501)?C?3$|501C3|^3$|PUBLICCHARITY|CHARIT|PRIVATEFOUND|FOUNDATION|CHURCH|509A|170B", u), "501c3",
        grepl("^501C?[0-9]+|TAXEXEMPT|NONPROFIT|EXEMPT|^527|^115", u), "other_exempt",
        grepl("GOV|CITY|COUNTY|STATE|MUNICIP|SCHOOLDIST|TOWN|VILLAGE|FEDERAL|TRIBE", u), "government",
        grepl("INDIVID|PERSON|MEMBER|STUDENT|SCHOLAR", u), "individual",
        grepl("LLC|CORP|INC|PARTNER|LLP|LP$|COMPANY|BUSINESS|FORPROFIT|TRUST|BANK", u), "business",
        default = "other") }
# recipient-level rows from both parts
r1 <- p1[, .(OBJECTID, EIN2, TAX_YEAR, PART=1L, RECIP_EIN=SN_01_LTD_RECIP_EIN, RECIP_NAME=fcoalesce(SN_01_LTD_RECIP_NAME_ORG_L1, SN_01_LTD_RECIP_NAME_PERS), IRC=SN_01_LTD_RECIP_IRC_SECTION, FMV=as.numeric(SN_01_LTD_ASSET_DIST_FMV), DESC=SN_01_LTD_ASSET_DIST_DESC, ZIP=substr(SN_01_LTD_RECIP_ADDR_ZIP,1,5))]
r2 <- p2[, .(OBJECTID, EIN2, TAX_YEAR, PART=2L, RECIP_EIN=SN_02_DOA_RECIP_EIN, RECIP_NAME=fcoalesce(SN_02_DOA_RECIP_NAME_ORG_L1, SN_02_DOA_RECIP_NAME_PERS), IRC=SN_02_DOA_RECIP_IRC_SECTION, FMV=as.numeric(SN_02_DOA_ASSET_DIST_FMV), DESC=SN_02_DOA_ASSET_DIST_DESC, ZIP=substr(SN_02_DOA_RECIP_ADDR_ZIP,1,5))]
rr <- rbind(r1, r2); rr[RECIP_EIN %in% c("","000000000","999999999") | !grepl("^[0-9]{9}$", RECIP_EIN), RECIP_EIN := NA]
rr[, RTYPE := irc_type(IRC)]; rr[RTYPE=="unknown" & !is.na(RECIP_EIN), RTYPE:="unknown_with_ein"]
rr[, SELF := RECIP_EIN == gsub("[^0-9]","",EIN2)]
cat("recipient types (rows):\n"); print(round(prop.table(table(rr$RTYPE, rr$PART), 2), 3))
cat("transfers to self EIN:", sum(rr$SELF, na.rm=T), "\n")
# filing-level
fl <- rbind(p1h[, .(OBJECTID, EIN2, TAX_YEAR, P1=TRUE, DIR=flag(SN_01_ORG_DTK_DIR_SUCCESSOR_X), EMP=flag(SN_01_ORG_DTK_EMPL_SUCCESSOR_X), OWN=flag(SN_01_ORG_DTK_OWN_SUCCESSOR_X), COMP=flag(SN_01_ORG_DTK_REC_COMP_X))],
            p2h[, .(OBJECTID, EIN2, TAX_YEAR, P1=FALSE, DIR=flag(SN_02_ORG_DTK_DIR_SUCCESSOR_X), EMP=flag(SN_02_ORG_DTK_EMPL_SUCCESSOR_X), OWN=flag(SN_02_ORG_DTK_OWN_SUCCESSOR_X), COMP=flag(SN_02_ORG_DTK_REC_COMP_X))])
fl <- fl[, .(EIN2=EIN2[1], TAX_YEAR=TAX_YEAR[1], HAS_P1=any(P1), HAS_P2=any(!P1), DIR=any(DIR,na.rm=T), EMP=any(EMP,na.rm=T), OWN=any(OWN,na.rm=T), COMP=any(COMP,na.rm=T)), by=OBJECTID]
add <- unique(rr[, .(OBJECTID, EIN2, TAX_YEAR)])[!OBJECTID %in% fl$OBJECTID]
fl <- rbind(fl, add, fill=TRUE); fl[is.na(HAS_P1), `:=`(HAS_P1 = OBJECTID %in% r1$OBJECTID, HAS_P2 = OBJECTID %in% r2$OBJECTID)]
agg <- rr[, .(N_RECIP = uniqueN(fcoalesce(RECIP_EIN, toupper(RECIP_NAME))), N_NP_RECIP = uniqueN(RECIP_EIN[RTYPE %in% c("501c3","other_exempt","unknown_with_ein") & !SELF], na.rm=TRUE),
              FMV_TOTAL=sum(FMV,na.rm=T), FMV_NP=sum(FMV[RTYPE %in% c("501c3","other_exempt","unknown_with_ein") & !SELF],na.rm=T),
              TOP_RECIP_SHARE = { v <- tapply(FMV, fcoalesce(RECIP_EIN, toupper(RECIP_NAME)), sum, na.rm=TRUE); if (sum(v)>0) max(v)/sum(v) else NA_real_ },
              ALL_INDIV = all(RTYPE=="individual"), ANY_BUS = any(RTYPE=="business")), by=OBJECTID]
fl <- merge(fl, agg, by="OBJECTID", all.x=TRUE); fl[is.na(N_RECIP), N_RECIP:=0L]
fl[, LEADER := DIR | EMP | OWN]; fl[is.na(LEADER), LEADER:=FALSE]
# multi-donor: recipient EINs receiving from >=2 distinct Part I donors in same tax year
md <- rr[PART==1 & !is.na(RECIP_EIN) & !SELF, .(N_DONORS=uniqueN(EIN2)), by=.(RECIP_EIN, TAX_YEAR)]
cat("recipient-years with >=2 Part I donors:", md[N_DONORS>=2, .N], " (>=3:", md[N_DONORS>=3,.N], ")\n")
saveRDS(list(fl=fl, rr=rr, md=md), file.path(S,"stage1.rds"))
cat("\nFilings:", nrow(fl), "\n"); print(fl[, .N, by=.(HAS_P1, HAS_P2)])
cat("Leader moved (2a/2b/2c) by part:\n"); print(fl[, .(n=.N, leader=mean(LEADER), dir=mean(DIR,na.rm=T), emp=mean(EMP,na.rm=T)), by=.(HAS_P1,HAS_P2)])
cat("N nonprofit recipients distribution (P1 filers):\n"); print(table(pmin(fl[HAS_P1==TRUE]$N_NP_RECIP,5), useNA="ifany"))
cat("Top-recipient FMV share (P1, >1 recipient) quantiles:\n"); print(quantile(fl[HAS_P1==TRUE & N_RECIP>1]$TOP_RECIP_SHARE, c(.1,.25,.5,.75,.9), na.rm=T))
