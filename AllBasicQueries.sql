USE forensic_investigation_database;

-- cartesian product
SELECT CR.case_ID, CR.case_status, CT.crime_type
FROM Case_Record CR, Crime_type CT
WHERE CR.case_ID = CT.case_ID AND CR.case_status = 'Open'
  AND CT.crime_type IN ('Robbery', 'Assault', 'Burglary')
ORDER BY CR.case_ID, CT.crime_type;

-- natural join
Select H.case_ID, H.personnel_ID
From Case_Record CR NATURAL JOIN Handle H
WHERE CR.case_status='open';

-- theta join using USING
SELECT P.personnel_ID, P.p_name
FROM Forensic_analyst F JOIN personnel P USING(personnel_ID)
where P.end_date IS NULL;

-- theta join using ON
SELECT H.personnel_ID, count(C.case_ID) AS count_of_cases
FROM Handle H JOIN Case_Record C ON (C.case_ID=H.case_ID AND C.case_status = 'Open')
GROUP BY H.personnel_ID
HAVING count(C.case_ID) >1;

-- self join
SELECT E1.case_ID, E1.evidence_type, COUNT(*) AS Same_type_Count
FROM Evidence_items E1 JOIN Evidence_items E2 USING (case_ID, evidence_type)
WHERE E1.evidence_ID!=E2.evidence_ID
GROUP BY E1.case_ID, E1.evidence_type
HAVING COUNT(*)>=1;

-- disctinct keyword
SELECT DISTINCT P.personnel_ID, Per.p_name, Per.p_role, H.evidence_ID
FROM Part_of P JOIN Has H USING (custody_ID)
JOIN Personnel Per USING(personnel_ID)
ORDER BY P.personnel_ID, H.evidence_ID;

-- like keyword
SELECT W.issue_date, W.exp_date, C.case_ID, C.open_date, W.warrant_ID, W.warrant_type, C.case_status
FROM Warrant W Natural Join Case_Record C
WHERE W.warrant_type LIKE '%Search%' OR W.warrant_type LIKE '%Arrest%'
ORDER BY W.issue_date;

-- order by
Select evidence_ID, custody_timestamp, transfer_reason
From Chain_of_custody Natural Join Has
order by evidence_ID, custody_timestamp;

-- union
SELECT case_ID, 'Warrant Issued' AS activity_type, warrant_type AS description, issue_date AS activity_date
FROM Warrant
UNION
SELECT case_ID, 'Case Event' AS activity_type, event_type AS description, event_date AS activity_date
FROM Case_Event
UNION
SELECT case_ID, 'Evidence Collected' AS activity_type, evidence_type AS description, collection_date AS activity_date
FROM Evidence_items
Order BY case_ID;

-- intersect
SELECT C.case_ID 
FROM Case_Record C
WHERE DATEDIFF(close_date, open_date) >= 30
	AND C.case_ID IN (
SELECT case_ID
FROM Has H JOIN Case_Record CR USING (case_id)
GROUP BY case_ID
HAVING count(*)>1);
/*SELECT case_ID 
FROM Case_Record 
WHERE DATEDIFF(close_date, open_date) >= 30
INTERSECT
SELECT case_ID
FROM Has H JOIN Case_Record CR USING (case_id)
GROUP BY case_ID
HAVING count(*)>1;
*/

-- except
SELECT P.personnel_ID, P.p_name, D.dname
FROM Personnel P NATURAL JOIN department D
WHERE p.end_date IS NOT NULL AND NOT EXISTS(
	SELECT P.personnel_ID
	FROM Case_event C JOIN Participate Pa USING(case_ID)
    WHERE p.personnel_ID=Pa.personnel_ID)
ORDER BY dname;
/*SELECT P.personnel_ID, P.p_name, D.dname
FROM Personnel P NATURAL JOIN department D
WHERE p.end_date IS NOT NULL
EXCEPT
SELECT P.personnel_ID, P.p_name, D.dname
FROM Personnel P JOIN department D USING(did) Join Participate Pa USING(personnel_ID)
WHERE P.end_date IS NOT NULL
ORDER BY dname;
*/

-- general aggregate function without group by 
Select count(Distinct personnel_ID) AS Number_of_personnel, count(Distinct Judge_ID) AS Number_of_Judges
From Handled_by;

-- grouping aggregate function with group by 
SELECT ct.crime_type, COUNT(cr.case_ID) AS total_cases,
    AVG(DATEDIFF(cr.close_date, cr.open_date)) AS avg_days_to_close
FROM Case_Record cr JOIN Crime_type ct USING(case_ID)
WHERE cr.case_status = 'Closed'
GROUP BY ct.crime_type
ORDER BY avg_days_to_close DESC;

-- grouping aggregate function with group by and having 
SELECT CT.crime_type, COUNT(case_ID) AS number_of_cases
FROM Case_Record  CR NATURAL JOIN crime_type CT
WHERE case_status = 'open'
GROUP BY CT.crime_type
Having COUNT(DISTINCT Case_ID)>3;

-- extra query
SELECT case_ID, case_status, DATEDIFF(close_date, open_date) AS working_time
FROM Case_Record
WHERE case_status = 'closed' AND DATEDIFF(close_date, open_date)>=30
UNION
SELECT case_ID, case_status, DATEDIFF(CURDATE(), open_date) AS working_time
FROM case_record
WHERE case_status ='open' AND DATEDIFF(CURDATE(), open_date)>=30;