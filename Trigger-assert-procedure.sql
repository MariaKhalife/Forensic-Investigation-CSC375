USE forensic_investigation_database;

-- assertion
/*CREATE ASSERTION CheckDetectiveRoleExclusivity
CHECK (
    NOT EXISTS (
        SELECT 1
        FROM Detectives D JOIN Forensic_analyst FA USING (personnel_ID)
        UNION 
        SELECT 1
        FROM Detectives D JOIN Administrative_staff A USING (personnel_ID)
    )
);*/
DELIMITER //
CREATE TRIGGER CheckDetectiveRoleExclusivity
BEFORE INSERT ON Detectives
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT personnel_ID FROM (
            SELECT personnel_ID FROM Forensic_analyst
            UNION
            SELECT personnel_ID FROM Administrative_staff
        ) AS OtherRoles
        WHERE OtherRoles.personnel_ID = NEW.personnel_ID
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Personnel already has another specialized role';
    END IF;
END//
DELIMITER ;
-- to check assertion
INSERT INTO detectives(personnel_ID) VALUES
(7); -- forensic_analyst


-- assertion
/*CREATE ASSERTION CheckForensicAnalystRoleExclusivity
CHECK (
    NOT EXISTS (
        SELECT 1
        FROM Forensic_analyst FA JOIN Detectives D USING (personnel_ID)
        UNION 
        SELECT 1
        FROM Forensic_analyst FA JOIN Administrative_staff A USING (personnel_ID)
    )
);*/
DELIMITER //
CREATE TRIGGER CheckForensicAnalystRoleExclusivity
BEFORE INSERT ON Forensic_analyst
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT personnel_ID FROM (
            SELECT personnel_ID FROM Detectives
            UNION
            SELECT personnel_ID FROM Administrative_staff
        ) AS OtherRoles
        WHERE OtherRoles.personnel_ID = NEW.personnel_ID
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Personnel already has another specialized role';
    END IF;
END// 
DELIMITER ;
-- to test assertion
INSERT INTO administrative_staff(personnel_ID) VALUES
(10); -- detective


-- assertion
/*CREATE ASSERTION CheckAdministrativeStaffRoleExclusivity
CHECK (
    NOT EXISTS (
        SELECT 1
        FROM Administrative_staff A JOIN Forensic_analyst FA USING (personnel_ID)
        UNION 
        SELECT 1
        FROM Administrative_staff A JOIN JOIN Detectives D USING (personnel_ID)
    )
);*/
DELIMITER //
CREATE TRIGGER CheckAdministrativeStaffRoleExclusivity
BEFORE INSERT ON Administrative_staff
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT personnel_ID FROM (
            SELECT personnel_ID FROM Forensic_analyst
            UNION
            SELECT personnel_ID FROM Detectives
        ) AS OtherRoles
        WHERE OtherRoles.personnel_ID = NEW.personnel_ID
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Personnel already has another specialized role';
    END IF;
END // 
DELIMITER ;
INSERT INTO forensic_analyst(personnel_ID) VALUES
(30); -- administrative_staff

-- view
Create View Case_Summary As
Select C.case_ID, C.case_status, C.open_date, Ct.crime_type, 
Count(E.evidence_ID) AS evidence_count, Count(L.analysis_ID) AS Analysis_count
From Case_Record C
Left Join Crime_type Ct Using (case_ID)
Left Join Evidence_items E  Using (case_ID)
Left Join Lab_analysis L Using (case_ID, evidence_ID)
Group by C.case_ID, C.case_status, C.open_date, Ct.crime_type;
-- to test view
SELECT * FROM Case_Summary 
WHERE case_status = 'Open' 
ORDER BY evidence_count DESC;

-- view
CREATE VIEW Personnel_Activity AS
SELECT P.personnel_ID, P.p_name, P.p_role, D.dname AS department,
    COUNT(DISTINCT Pa.case_ID) AS cases_assigned,
    COUNT(DISTINCT Po.custody_ID) AS custody_events
FROM Personnel P
JOIN Department D Using (did)
LEFT JOIN Participate Pa Using (personnel_ID)
LEFT JOIN Part_of Po Using (personnel_ID)
GROUP BY P.personnel_ID, P.p_name, P.p_role, D.dname;
-- to test view
SELECT * FROM Personnel_Activity 
WHERE cases_assigned >= 2
ORDER BY custody_events DESC;

-- view
CREATE VIEW Evidence_Custody_Hist AS
SELECT E.evidence_ID, E.evidence_type, C.custody_timestamp, C.transfer_reason, 
P.p_name AS handled_by, D.dname AS department
FROM Evidence_items E
JOIN Has H Using (evidence_ID, case_ID)
JOIN Chain_of_Custody C Using (custody_ID)
JOIN Part_of Po Using (custody_ID)
JOIN Personnel P Using (personnel_ID)
JOIN Department D Using (did)
ORDER BY E.evidence_ID, C.custody_timestamp;
-- to test view
SELECT * FROM Evidence_Custody_Hist 
WHERE evidence_ID = 10
ORDER BY custody_timestamp;

-- trigger
DELIMITER $$
CREATE TRIGGER case_is_open
BEFORE INSERT ON warrant 
FOR EACH ROW 
BEGIN
	DECLARE curr_status VARCHAR(10);
    SELECT C.case_status INTO curr_status
    FROM Case_record C
    WHERE C.case_ID = NEW.case_ID;
		CASE 
			when curr_status !='open' THEN 
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot issue warrant for non-Open case.';
		END CASE;
END$$;
DELIMITER ;
-- to test trigger
INSERT INTO warrant(warrant_type, issue_date, exp_date, case_ID) VALUES
('Search', '2023-11-20', '2023-12-20', 1),
('Device Search', '2023-11-25', '2023-12-25', 1);

-- procedure
DELIMITER $$
CREATE PROCEDURE generate_monthly_report(IN month_date INT, IN year_date INT)
BEGIN
	DECLARE total_cases_opened INT;
    DECLARE total_cases_closed INT;
    DECLARE total_evidence_collected INT;
    DECLARE total_lab_analysis INT;
    DECLARE active_personnel INT;
    DECLARE avg_case_duration INT;
    DECLARE total_warrants_issued iNT;
    
    SELECT COUNT(*) INTO total_cases_opened
    FROM case_record
    WHERE (case_status = 'open' OR case_status = 'closed')
    AND MONTH(open_date) = month_date 
    AND YEAR(open_date) = year_date;
    
    SELECT COUNT(*) INTO total_cases_closed
    FROM case_record
    WHERE case_status = 'closed' AND MONTH(close_date) = month_date 
    AND YEAR(close_date) = year_date;
    
    SELECT COUNT(*) INTO total_evidence_collected
    FROM evidence_items
    WHERE MONTH(collection_date) = month_date 
    AND YEAR(collection_date) = year_date;
    
    SELECT COUNT(*) INTO total_lab_analysis
    FROM lab_analysis
    WHERE MONTH(analysis_date) = month_date
    AND YEAR(analysis_date) = year_date;
    
    SELECT COUNT(*) INTO active_personnel
    FROM personnel
    WHERE end_date IS NULL;
    
    SELECT AVG(DATEDIFF(close_date, open_date)) INTO avg_case_duration
    FROM case_record
    WHERE MONTH(close_date) = month_date 
    AND YEAR(close_date) = year_date;
    
    SELECT count(*) INTO total_warrants_issued
    FROM warrant
    where MONTH(issue_date)= month_date 
    AND YEAR(issue_date) = year_date;
        
	SELECT '=====MONTHLY REPORT======' AS header;
	SELECT 'METRIC' AS metric, 'VALUE' AS v
    UNION ALL
    SELECT '---', '---'
    UNION ALL
    SELECT 'Cases Opened', total_cases_opened
    UNION ALL
    SELECT 'Cases Closed', total_cases_closed
    UNION ALL
    SELECT 'Evidence Collected', total_evidence_collected
    UNION ALL
    SELECT 'Evidence Analyzed', total_lab_analysis
    UNION ALL
    SELECT 'Active Personnel', active_personnel
    UNION ALL
    SELECT 'Warrants Issued', total_warrants_issued
    UNION ALL
    SELECT 'Average Case Duration ', avg_case_duration
    UNION ALL
    SELECT '---', '---';

END $$
DELIMITER ;
-- to call procedure
CALL generate_monthly_report(8,2024);