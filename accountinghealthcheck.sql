/* Accounting Health Check */
/*	
    The first half of these SQLs are to pin-point setup related issues with the chart of accounts.
    
    The other half point out Product CRs or issues caused by Product CRs.
*/
/* SETUP ISSUES */

/*Detail Account Consolidating to More than 1 Consolidated Account*/-- used to be 14
SELECT 'Account code ' || coa.acctdept || ' is consolidated to more than one account' AS description,
	'(# of Consolidation): ' || COUNT(xr.acctdeptid) AS consolidation_count,
	xr.acctdeptid AS cons_acctdeptid
FROM glconsxref xr
LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = xr.acctdeptid
GROUP BY xr.acctdeptid,
	coa.acctdeptid
HAVING COUNT(xr.acctdeptid) > 1;

/* DEFECTS AND PRODUCT CRs */
/*glconsxref entry mapped to invalid GL Account*/-- used to be 13 and 8 and 6
SELECT 'glconsxref entry mapped to invalid GL Account OR invalid accountingid' AS description,
	xref.glconsxrefid,
	xref.acctdeptid,
	CASE 
		WHEN det.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		WHEN det.headerdetailtotalcons != 2
			AND det.accountingid != xref.accountingid
			THEN 'NON-DETAIL ACCOUNT, ACCOUNTINGID INVALID'
		WHEN det.headerdetailtotalcons != 2
			AND det.accountingid = xref.accountingid
			THEN 'NON-DETAIL ACCOUNT'
		WHEN det.accountingid != xref.accountingid
			THEN 'ACCOUNTINGID INVALID'
		ELSE 'Valid COA Mapping'
		END AS check_acctdeptid,
	xref.consacctdeptid,
	CASE 
		WHEN cons.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		WHEN cons.headerdetailtotalcons != 4
			AND cons.accountingid != xref.accountingid
			THEN 'NON-CONSOLIDATED ACCOUNT, ACCOUNTINGID INVALID'
		WHEN cons.headerdetailtotalcons != 4
			AND cons.accountingid = xref.accountingid
			THEN 'NON-CONSOLIDATED ACCOUNT'
		WHEN cons.accountingid != xref.accountingid
			THEN 'ACCOUNTINGID INVALID'
		ELSE 'Valid COA Mapping'
		END AS check_consacctdeptid,
	xref.accountingid
FROM glconsxref xref
LEFT JOIN glchartofaccounts det ON xref.acctdeptid = det.acctdeptid
LEFT JOIN glchartofaccounts cons ON xref.consacctdeptid = cons.acctdeptid
WHERE det.acctdeptid IS NULL
	OR cons.acctdeptid IS NULL
	OR cons.headerdetailtotalcons != 4
	OR det.headerdetailtotalcons != 2
	OR cons.accountingid != xref.accountingid
	OR det.accountingid != xref.accountingid
ORDER BY det.acctdeptid,
	cons.acctdeptid;

/*glhistory entries have an invalid ids or idluids*/-- output 15
SELECT h.glhistoryid,
	CASE 
		WHEN length(h.description) > 23
			THEN left(h.description, 25) || '....'
		ELSE h.description
		END AS description,
	h.amtdebit,
	h.amtcredit,
	coa.acctdept,
	CASE 
		WHEN h.accountingid != coa.accountingid
			THEN 'accountingid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.accountingidluid != coa.accountingidluid
			THEN 'accountingidluid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.locationid != sm.childstoreid
			THEN 'locationid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.locationidluid != sm.childstoreidluid
			THEN 'locationidluid incorrect, '
		ELSE ''
		END AS bad_ids
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN costore s ON coa.accountingid = s.storeid
INNER JOIN costoremap sm ON sm.parentstoreid = coa.accountingid
INNER JOIN costore s2 ON sm.childstoreid = s2.storeid
WHERE (
		h.accountingidluid != coa.accountingidluid
		OR h.locationidluid != sm.childstoreidluid
		);

/*Multiple Entries in GL Balance for 1 Acctdeptid*/
SELECT 'duplicate glbalance entry for acctdeptid ' || b.acctdeptid AS description,
	coa.acctdept,
	b.fiscalyear,
	count(fiscalyear) AS num_of_duplicates
FROM glbalance b
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
GROUP BY coa.acctdept,
	b.fiscalyear,
	b.acctdeptid,
	b.storeid
HAVING count(b.fiscalyear) > 1;

/*glbalance entries with a storeid not valid with costoremap*/
SELECT 'gl balance entry with invalid store, check output 15 as potential cause' AS description,
	glbalancesid,
	coa.acctdept,
	b.fiscalyear
FROM glbalance b
LEFT JOIN costoremap sm ON sm.parentstoreid = b.accountingid
    AND sm.childstoreid = b.storeid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
WHERE sm.childstoreid IS NULL;

/*acctdeptid in glhistory not in glchartofaccounts*/
SELECT 'acctdeptid in glhistory not in glchartofaccounts' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid,
	hist.amtdebit,
	hist.amtcredit
FROM glhistory hist
LEFT JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
WHERE coa.acctdeptid IS NULL;

/*acctdeptid not in glbalance table*/
SELECT 'acctdeptid not in glbalance table' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid
FROM glhistory hist
INNER JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
LEFT JOIN glbalance bal ON coa.acctdeptid = bal.acctdeptid
WHERE bal.acctdeptid IS NULL;

/*glhistory entries tied to non-detail account*/
SELECT 'acctdeptid links to non-detail account' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	coa.acctdept,
	hist.accountingid,
	CASE 
		WHEN coa.headerdetailtotalcons = 1
			THEN 'Header'
		WHEN coa.headerdetailtotalcons = 2
			THEN 'Detail'
		WHEN coa.headerdetailtotalcons = 3
			THEN 'Total'
		WHEN coa.headerdetailtotalcons = 4
			THEN 'Consolidated'
		ELSE ''
		END AS accounttype
FROM glhistory hist,
	glchartofaccounts coa
WHERE hist.acctdeptid = coa.acctdeptid
	AND coa.headerdetailtotalcons != 2
ORDER BY hist.accountingid,
	coa.acctdept;

/*oob transaction*/
SELECT 'transaction does not balance' AS description,
	journalentryid,
	accountingid,
	MAX(DATE),
	ROUND((SUM(amtdebit) * .0001), 4) AS debits,
	ROUND((SUM(amtcredit) * .0001), 4) AS credits,
	ROUND(((SUM(amtdebit) * .0001) - (SUM(amtcredit) * .0001)), 4) AS discrepancy_amt,
	CASE 
		WHEN MAX(DATE) > s.conversiondate
			THEN 'may be valid'
		ELSE 'potential conversion defect'
		END AS validity
FROM glhistory h
INNER JOIN costoremap sm ON sm.parentstoreid = h.accountingid
INNER JOIN costore s ON s.storeid = sm.childstoreid
GROUP BY journalentryid,
	accountingid,
	s.conversiondate
HAVING SUM(amtdebit) - SUM(amtcredit) != 0
	AND LEFT(MAX(DATE::VARCHAR), 10) IN (
		SELECT
			LEFT(DATE::VARCHAR, 10)
		FROM glhistory h
		GROUP BY accountingid,
			LEFT(DATE::VARCHAR, 10)
		HAVING SUM(amtdebit) - SUM(amtcredit) != 0
		ORDER BY MAX(DATE) DESC
		)
ORDER BY MAX(DATE) DESC;

/* day does not balance */
SELECT 'day does not balance' AS description,
SUM(amtdebit) - SUM(amtcredit) AS oob_amount,
	LEFT(DATE::VARCHAR, 10),
	h.accountingid
FROM glhistory h
GROUP BY accountingid,
	LEFT(DATE::VARCHAR, 10)
HAVING SUM(amtdebit) - SUM(amtcredit) != 0
ORDER BY MAX(DATE) DESC;

/*journal entry to the current earnings account*/
SELECT 'glhistory posted to the current earnings account' AS description,
	hist.glhistoryid,
	hist.journalentryid,
	hist.DATE,
	hist.acctdeptid,
	hist.amtdebit,
	hist.amtcredit,
	hist.description,
	hist.accountingid,
	hist.locationid
FROM glhistory hist,
	acpreference pref
WHERE pref.id = 'acct-CurrentEarningsAcctID'
	AND hist.acctdeptid::TEXT = pref.value
	AND hist.accountingid = pref.accountingid;