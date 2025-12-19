Use Forensic_Investigation_Database;

-- set membership
SELECT C.case_ID
FROM Case_Record C
WHERE C.case_ID NOT IN (
    SELECT case_ID
    FROM (
        SELECT E.case_ID
        FROM Evidence_items E 
        LEFT JOIN Lab_analysis LA USING (evidence_ID, case_ID) 
        LEFT JOIN Personnel P USING (personnel_ID)
        WHERE (LA.analysis_ID IS NULL) OR (P.personnel_ID IS NOT NULL AND P.clearance_lvl>1)
 ) AS Cases
);

-- set comparision
SELECT C.case_ID, Ct.crime_type,
    MIN(W.issue_date) AS first_warrant_date,
    MIN(E.collection_date) AS first_evidence_date
FROM Case_Record C
JOIN Crime_type Ct USING (case_ID)
JOIN Warrant W USING (case_ID)
JOIN Evidence_items E USING (case_ID)
WHERE E.collection_date > ANY (
    SELECT issue_date
    FROM Warrant W2
    WHERE W2.case_ID = C.case_ID
)
GROUP BY C.case_ID, Ct.crime_type
ORDER BY C.case_ID;

-- set cardinality
SELECT E.case_ID
FROM evidence_items E
Where E.evidence_type = 'biological sample' 
AND EXISTS( SELECT E.evidence_ID
			FROM Lab_analysis L
            WHERE L.evidence_ID = E.evidence_ID AND L.technique_used = 'Blood typing' 
            OR L.technique_used = 'Fingerprint comparison');
   
-- set cardinality
SELECT * 
FROM Case_Record CR
WHERE NOT EXISTS (
    SELECT 1 FROM Evidence_items EI
    WHERE EI.case_ID = CR.case_ID
);

-- two or more nesting level
SELECT D.did, D.dname, COUNT(DISTINCT YP.personnel_ID) AS nb_of_high_achieving_personnel
FROM Department D JOIN (
	SELECT P.personnel_ID, P.did, YEAR(C.close_date) AS close_year, COUNT(DISTINCT H.case_ID) AS cases_solved
	FROM Handle H
	JOIN Case_Record C USING(case_ID)
	JOIN Personnel P USING(personnel_ID)
	WHERE C.case_status = 'Closed'
	GROUP BY P.personnel_ID, P.did, YEAR(C.close_date)
) AS YP USING(did)
JOIN (SELECT YearlyCount.did, YearlyCount.close_year, AVG(YearlyCount.case_count) AS avg_cases_per_personnel
		FROM (SELECT P1.personnel_ID, P1.did, YEAR(C1.close_date) AS close_year, 
        COUNT(DISTINCT H1.case_ID) AS case_count
			FROM Handle H1
			JOIN Case_Record C1 USING(case_ID)
			JOIN Personnel P1 USING(personnel_ID)
			WHERE C1.case_status = 'Closed'
			GROUP BY P1.personnel_ID, P1.did, YEAR(C1.close_date)
		) AS YearlyCount
        GROUP BY YearlyCount.did, YearlyCount.close_year
    ) AS DeptAvg ON D.did = DeptAvg.did AND YP.close_year = DeptAvg.close_year
WHERE YP.cases_solved >= DeptAvg.avg_cases_per_personnel
GROUP BY D.did, D.dname;

-- division operation
/*Select P.personnel_ID,P.p_name, P.p_role
From Personnel P
Where Not Exists (
	Select Distinct E.evidence_type
    From Evidence_Items E
    Where E.evidence_type IS Not Null
    EXCEPT
    Select Distinct E.evidence_type
    From Part_of Po
    Join Has H Using (custody_ID)
    Join Evidence_item Using (evidence_ID)
    Where Po.personnel_ID = P.personnel_ID
);*/

Select P.personnel_ID, P.p_name, P.p_role
From Personnel P
Where Not Exists (
	Select 1
    From Evidence_Items E
    Where E.evidence_type IS Not Null
    AND Not Exists(
    Select 1
    From Part_of Po
    Join Has H Using (custody_ID)
    Join Evidence_items E2 Using (evidence_ID)
    Where Po.personnel_ID = P.personnel_ID 
    AND E2.evidence_type = E.evidence_type)
);

-- nested query in from clause
SELECT C.case_ID, C.case_status, W.total_warrants
FROM case_record C JOIN 
	(SELECT case_ID, COUNT(*) AS total_warrants
	FROM warrant
    GROUP BY case_ID) W USING(case_ID)
WHERE W.total_warrants > 
	(SELECT AVG(cnt)
	FROM 
    (SELECT COUNT(*) AS cnt
	FROM warrant
    GROUP BY case_ID) avg_table);
    
-- nested query in select clause
SELECT C.case_ID, 
		(SELECT count(*)
        FROM Evidence_items E
        WHERE C.case_ID = E.case_ID
    ) AS nb_of_evidence_items, 
		(SELECT count(personnel_ID)
        FROM Personnel P JOIN Handle H USING (personnel_ID)
        where P.end_date IS NULL AND H.case_ID=C.case_ID
    ) AS nb_of_working_personnel
FROM Case_Record C
WHERE case_status = 'Closed';

-- update query using CASE
UPDATE Department D
SET budget = 
    CASE
        WHEN budget < 300000 THEN budget + 150000
        WHEN budget > 300000 AND budget < 400000 THEN budget + 100000
        ELSE budget + 50000
    END
WHERE EXISTS (
    SELECT 1
    FROM Personnel P
    JOIN Participate Pa Using (personnel_ID)
    JOIN Case_Record Cr Using (case_ID)
    WHERE P.did = D.did
      AND Cr.case_status = 'Open'
      AND Cr.open_date >= CURDATE() - INTERVAL 180 DAY
);
    
-- outer join
SELECT E.evidence_ID, E.evidence_type, C.custody_ID, C.custody_timestamp, P.personnel_ID
FROM evidence_items E LEFT OUTER JOIN (has H JOIN 
(chain_of_custody C JOIN Part_Of P USING(custody_ID)) USING(custody_ID)) 
USING (evidence_ID);


-- extra query
Select evidence_ID, evidence_type,
CASE
	When custody_count = 0 Then 'MISSING'
    When custody_count = 1 Then 'INCOMPLETE'
    When custody_count = 2 Then 'MINIMAL'
    When custody_count >= 3 Then 'GOOD'
END as chain_status, custody_count,
CASE
	When Exists(
		Select 1
        From Has H
        Join Chain_of_custody Ch Using (custody_ID)
        where H.evidence_ID = E.evidence_ID AND 
        Ch.transfer_reason = 'sent to lab')
        Then 'Lab Transfer Found'
	Else 'No Lab Transfer'
END AS lab_transfer
From Evidence_items E
JOIN(Select evidence_ID, Count(*) as custody_count
    From Has
    Group by evidence_ID) EC Using (evidence_ID)
Order by custody_count;