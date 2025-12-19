CREATE DATABASE Forensic_Investigation_Database;

CREATE TABLE Case_Record(
	case_ID INT PRIMARY KEY AUTO_INCREMENT,
    open_date DATE,
    close_date DATE,
    investigation_TID INT NOT NULL,
	case_status VARCHAR(10) AS (
		CASE
			WHEN open_date IS NULL AND close_date IS NULL THEN 'Pending'
            WHEN open_date IS NOT NULL AND close_date IS NULL THEN 'Open'
            WHEN open_date IS NOT NULL AND close_date IS NOT NULL THEN 'Closed'
		END) STORED
);


CREATE TABLE Crime_type(
	crime_type varchar(20),
    case_ID INT,
    PRIMARY KEY(case_ID, crime_type),
    FOREIGN KEY(case_ID) REFERENCES Case_Record(case_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Department(
    did INT PRIMARY KEY AUTO_INCREMENT,
    dname varchar(30) NOT NULL UNIQUE,
    budget INT
    CHECK(budget>0)
);

CREATE TABLE Warrant(
	warrant_ID int auto_increment,
	warrant_type varchar(15) NOT NULL,
	issue_date date NOT NULL,
	exp_date date NOT NULL,
	case_ID int NOT NULL,
	primary key (warrant_ID),
	foreign key (case_ID) references Case_Record(case_ID)
		on update cascade
		on delete cascade,
    CHECK (
        warrant_type IN (
            'Search', 'Arrest', 'Seizure', 'Detention', 'Surveillance', 'Tracking', 'Wiretap', 'Subpoena', 'Device Search', 'Data Access'
        )
    )
);

create table Case_Event(
	case_event_ID int auto_increment,
    event_type varchar(25) not null,
    event_date date not null,
    notes varchar(100),
    case_ID int,
    primary key (case_event_ID, case_ID),
    foreign key (case_ID) references Case_Record(case_ID)
		on update cascade
		on delete cascade,
	check (event_type IN ('interrogation', 'search', 'court filing',
    'Suspect handling' ,'Witness interview', 'Scene search', 'Evidence collection',
    'Surveillance operation', 'Area canvass', 'Stakeout operation', 'Lead update',
    'Tip received'))
	);

create table Evidence_items(
	case_ID int,
	evidence_ID int auto_increment,
	storage_loct varchar(50),
	evidence_type varchar(20) not null,
	collection_date date not null,
	primary key (evidence_ID, case_ID),
	foreign key (case_ID) references Case_Record(case_ID)
		on update cascade
		on delete cascade,
	check (evidence_type IN ('weapon', 'digital file', 'biological sample','physical','chemical'))
	);

CREATE TABLE Chain_Of_Custody(
	custody_ID INT PRIMARY KEY AUTO_INCREMENT,
    custody_timestamp TIME NOT NULL,
    transfer_reason varchar(35) NOT NULL,
    CHECK(transfer_reason IN ('sent to lab', 'stored', 'retrieved for court', 'archived', 'destroyed', 'transferred to another department'))
    );
    
CREATE TABLE Personnel(
	personnel_ID INT PRIMARY KEY AUTO_INCREMENT,
    p_name varchar(20) NOT NULL,
    p_role varchar(20),
    start_date date NOT NULL,
    end_date date,
    clearance_lvl INT DEFAULT 4,
    did INT NOT NULL,
    FOREIGN KEY(did) REFERENCES Department(did) ON DELETE RESTRICT ON UPDATE CASCADE,
    CHECK(clearance_lvl >= 1 AND clearance_lvl <= 4)
);

create table Lab_analysis(
	analysis_ID int auto_increment primary key,
	findings varchar(100),
	technique_used varchar(30),
	analysis_date date not null,
	personnel_ID int not null,
	case_ID int not null,
	evidence_ID int not null,
	foreign key (case_ID) references Case_Record(case_ID)
		on update cascade
		on delete cascade,
	foreign key (evidence_ID) references Evidence_items(evidence_ID)
		on update cascade
		on delete cascade,
    foreign key (personnel_ID) references Personnel(personnel_ID)
		on update cascade
		on delete restrict,
    unique(personnel_ID, evidence_ID, case_ID),
    check(technique_used IN ('DNA profiling', 'Blood typing', 'Fingerprint comparison',
    'Footprint analysis', 'Drug testing', 'Bullet comparison', 'Firearm examination',
    'Toxicology test', 'Explosive residue', 'Gunshot residue', 'Computer forensics',
    'Network analysis', 'Trace detection', 'Evidence preservation', 'Scene reconstruction'))
	);
    
create table Detectives(
	handler_ID int auto_increment,
    personnel_ID int,
    foreign key (personnel_ID) references Personnel(personnel_ID)
		on update cascade
		on delete cascade,
    primary key (personnel_ID),
    unique(handler_ID)
    );

CREATE TABLE Contact_Info(
	contact_info VARCHAR(100),
    personnel_ID INT,
    PRIMARY KEY(contact_info, personnel_ID),
    FOREIGN KEY(personnel_ID) REFERENCES Personnel(personnel_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Administrative_staff(
    personnel_ID INT PRIMARY KEY,
    staff_ID INT UNIQUE AUTO_INCREMENT,
    oversee_did INT,
    FOREIGN KEY(personnel_ID) REFERENCES Personnel(personnel_ID) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY(oversee_did) REFERENCES Department(did) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Forensic_analyst(
    personnel_ID int,
    analyst_ID int auto_increment,
    primary key (personnel_ID),
    foreign key (personnel_ID) references Personnel(personnel_ID)
		on update cascade
		on delete cascade,
    unique(analyst_ID)
);

CREATE TABLE Judge(
    judge_ID int auto_increment,
    jname varchar(15) NOT NULL,
    jrole varchar(15) NOT NULL,

    primary key (judge_ID),
    CHECK (
        jrole IN (
            'Chief Judge', 'Trial Judge','Magistrate', 'Justice', 'Appellate', 'Senior Judge'
        )
    )
);

CREATE TABLE Jcontact_Info(
	contact_info varchar(100) NOT NULL,
    judge_ID int NOT NULL,
    primary key(judge_ID, contact_info),
    foreign key(judge_ID) references Judge(judge_ID)
        on update cascade
		on delete cascade
);


CREATE TABLE Has(
    custody_ID INT UNIQUE,
    case_ID INT,
    evidence_ID INT,
    PRIMARY KEY(custody_ID, case_ID, evidence_ID),
    FOREIGN KEY(custody_ID) REFERENCES Chain_Of_Custody(custody_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(case_ID) REFERENCES Case_Record(case_ID)ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(evidence_ID) REFERENCES Evidence_items(evidence_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Participate(
    personnel_ID INT,
    case_ID INT,
    case_event_ID INT,
    PRIMARY KEY(personnel_ID, case_ID, case_event_ID),
    FOREIGN KEY(personnel_ID) REFERENCES Personnel(personnel_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(case_ID) REFERENCES Case_Record(case_ID)ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY(case_event_ID) REFERENCES Case_Event(case_event_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

create table Handled_by(
	warrant_ID int,
    personnel_ID int,
    judge_ID int,
    primary key (warrant_ID, personnel_ID, judge_ID),
    foreign key (warrant_ID) references Warrant(warrant_ID)
		on update cascade
		on delete cascade,
    foreign key (personnel_ID) references Personnel(personnel_ID)
		on update cascade
		on delete cascade,
    foreign key (judge_ID) references Judge(judge_ID)
		on update cascade
		on delete cascade
);

create table Part_of(
	personnel_ID int,
    custody_ID int,
    primary key(personnel_ID, custody_ID),
    foreign key (personnel_ID) references Personnel(personnel_ID)
		on update cascade
		on delete cascade,
    foreign key (custody_ID) references Chain_of_custody(custody_ID)
		on update cascade
		on delete cascade
);
    
CREATE TABLE Handle(
    personnel_ID INT,
    case_ID INT,

    primary key (personnel_ID, case_ID),
    foreign key (personnel_ID) references Personnel(personnel_ID)
        on update cascade
		on delete cascade,
    foreign key (case_ID) references Case_Record(case_ID)
        on update cascade
		on delete cascade
);