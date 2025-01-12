--
--
-- 8888888888 888     888  .d88888b.          .d8888b.  888888888 8888888888  .d8888b.   .d8888b. 
-- 888        888     888 d88P" "Y88b        d88P  Y88b 888             d88P d88P  Y88b d88P  Y88b
-- 888        888     888 888     888               888 888            d88P  888    888 Y88b. d88P
-- 8888888    Y88b   d88P 888     888             .d88P 8888888b.     d88P   Y88b. d888  "Y88888" 
-- 888         Y88b d88P  888     888         .od888P"       "Y88b 88888888   "Y888P888 .d8P""Y8b.
-- 888          Y88o88P   888     888 888888 d88P"             888  d88P            888 888    888
-- 888           Y888P    Y88b. .d88P        888"       Y88b  d88P d88P      Y88b  d88P Y88b  d88P
-- 8888888888     Y8P      "Y88888P"         888888888   "Y8888P" d88P        "Y8888P"   "Y8888P" 
--
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--  
-- This SQL is used to diagnose common problems and issues relating to and caused by EVO-25798. 
-- 
-- It includes multiple diagnostics in this order:
--
--      Output 1: Incorrect Storeid / Accountingid or luids
--
--      Output 2: Checks paid, partially paid, and not paid when they should be.
--          This includes checks paid 
--
--
--                                                                                    
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         d888  
-- d88P" "Y88b          888                      888        d8888  
-- 888     888          888                      888          888  
-- 888     888 888  888 888888 88888b.  888  888 888888       888  
-- 888     888 888  888 888    888 "88b 888  888 888          888  
-- 888     888 888  888 888    888  888 888  888 888          888  
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.        888  
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888     8888888
--                             888                                 
--                             888                                 
--                             888                                 
--                                                                                                                                                                        
--
--
--  Corrects erroneous packing slip invoice, storeid = 0
--
--
SELECT gls.sltrxid,
	gls.storeid,
	s.storeidluid AS good_id
FROM glsltransaction gls
INNER JOIN costore s USING (storeid)
WHERE s.storeid = 1;
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         .d8888b. 
-- d88P" "Y88b          888                      888        d88P  Y88b
-- 888     888          888                      888               888
-- 888     888 888  888 888888 88888b.  888  888 888888          .d88P
-- 888     888 888  888 888    888 "88b 888  888 888         .od888P" 
-- 888     888 888  888 888    888  888 888  888 888        d88P"     
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.      888"      
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888     888888888 
--                             888                                    
--                             888                                    
--                             888                                    
--
SELECT /* Remaining Amount*/ ROUND((sl.remainingamt * .0001), 2) AS remaining,
	--
	/* Invoice Amount */ ROUND((sl.docamt * .0001), 2) AS docamt,
	--
	/* Paid from Checks */ ROUND(sum(amtpaidthischeck * .0001), 2) AS paidsofar,
	--
	/* Correct Remaing Amount */
	CASE 
		WHEN voids.id IS NOT NULL
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck))) != docamt
			THEN ROUND(((docamt - sum(amtpaidthischeck)) * .0001), 2)
		ELSE 0
		END AS corr_remain,
	/* */
	/* Invoice Number */ sl.documentnumber,
	/* Invoice Description */ sl.description,
	--
	/* SLTRX State */
	CASE 
		WHEN voids.id IS NOT NULL -- if part of the voided checks list
			THEN 1
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0 -- If the sum of payments <= 0
			THEN 4 --FULLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
			THEN 2 -- PARTIALLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
			THEN 1 -- UNPAID
		ELSE 0 -- Panic if you get a zero
		END AS STATE,
	/* */
	sl.sltrxstate AS oldstate,
	--
	sl.sltrxid AS identifier,
	CASE 
		WHEN voids.id IS NOT NULL
			THEN voids.id
		ELSE sl.sltrxid
		END AS sltrxidentifier
--
FROM apcheckinvoicelist il
LEFT JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
LEFT JOIN (
	SELECT il.apinvoiceid AS id, -- ap invoice id or sltrxid
		sl.documentnumber
	FROM apcheckinvoicelist il -- list of invoices that have had checks paid on them
	INNER JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid -- join on checkheader to see the check states
	INNER JOIN glsltransaction sl ON sl.sltrxid = il.apinvoiceid -- join to reference the glsl info (remaining amounts and whatnot)
	WHERE sl.docamt != sl.remainingamt -- Where remaining amount != the invoice amount
		AND sltrxstate NOT IN (9, 4) -- Not voided or already paid
		AND sl.accttype = 2 -- Is an ap invoice
	GROUP BY il.apinvoiceid,
		sl.documentnumber
	/* Whether all checks are voided */
	HAVING sum(CASE 
				WHEN ch.voidedflag = 2
					THEN 1
				ELSE 0
				END) = count(il.apinvoiceid)::INT
	) voids ON voids.id = sl.sltrxid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
WHERE (
		(
			sltrxstate NOT IN (9)
			AND ch.voidedflag = 0
			)
		OR voids.id IS NOT NULL
		)
	AND v.vendornumber = 410928 -- Makes sure we don't included voided checks in the paid so far sum
GROUP BY apinvoiceid,
	sl.documentnumber,
	sl.description,
	sl.docamt,
	sl.remainingamt,
	sl.sltrxid,
	voids.id
HAVING sum(amtpaidthischeck) != (docamt - remainingamt)
	OR voids.id IS NOT NULL;
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         .d8888b. 
-- d88P" "Y88b          888                      888        d88P  Y88b
-- 888     888          888                      888             .d88P
-- 888     888 888  888 888888 88888b.  888  888 888888         8888" 
-- 888     888 888  888 888    888 "88b 888  888 888             "Y8b.
-- 888     888 888  888 888    888  888 888  888 888        888    888
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.      Y88b  d88P
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888      "Y8888P" 
--                             888                                    
--                             888                                    
--                             888                                    
--
--
SELECT sltrxid
FROM glsltransaction gls
INNER JOIN apvendor v ON v.vendorid = gls.acctid
LEFT JOIN glhistory h ON h.journalentryid = gls.docrefglid
WHERE h.glhistoryid IS NULL
	AND sltrxstate IN (1, 2)
	AND v.vendornumber = 1
GROUP BY gls.sltrxid
HAVING count(distinct vendornumber) = 1
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888            d8888 
-- d88P" "Y88b          888                      888           d8P888 
-- 888     888          888                      888          d8P 888 
-- 888     888 888  888 888888 88888b.  888  888 888888      d8P  888 
-- 888     888 888  888 888    888 "88b 888  888 888        d88   888 
-- 888     888 888  888 888    888  888 888  888 888        8888888888
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.            888 
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888           888 
--                             888                                    
--                             888                                    
--                             888                                    
--
SELECT ps.partshipmentid
FROM glsltransaction gls
INNER JOIN apvendor v ON v.vendorid = gls.acctid
INNER JOIN papartshipment ps ON ps.apinvoiceid = gls.sltrxid
LEFT JOIN glhistory h ON h.journalentryid = gls.docrefglid
WHERE h.glhistoryid IS NULL
	AND sltrxstate = 9
	AND v.vendornumber = 1
GROUP BY ps.partshipmentid
HAVING count(DISTINCT vendornumber) = 1
