/*DROP TABLE Location CASCADE;
DROP TABLE Role CASCADE;
DROP TABLE Usergroup CASCADE;
DROP TABLE Customer CASCADE;
DROP TABLE Project CASCADE;
DROP TABLE Department CASCADE;
DROP TABLE Employee CASCADE;
DROP TABLE EmployeeRoles CASCADE;
DROP TABLE EmployeesInProject CASCADE;
DROP TABLE EmployeesInUsergroup CASCADE;
DROP TABLE Commission CASCADE;*/

/*Tables*/
CREATE TABLE Employee(
	EmployeeID SERIAL PRIMARY KEY,
	DepartmentID int NOT NULL,
	Name VARCHAR(40) DEFAULT '(name empty)',
	Email VARCHAR(40) DEFAULT '(email empty)'
) PARTITION BY RANGE (EmployeeID);

CREATE TABLE Role(
	RoleID SERIAL PRIMARY KEY,
	Name VARCHAR(40) DEFAULT '(name empty)',
	Description VARCHAR(500) DEFAULT '(description empty)'
);

CREATE TABLE EmployeeRoles(
	EmployeeID int NOT NULL,
	RoleID int NOT NULL,
	PRIMARY KEY(EmployeeID, RoleID),
	CONSTRAINT FK_EmployeeID FOREIGN KEY(EmployeeID)
	REFERENCES Employee(EmployeeID)
		ON DELETE CASCADE
);

CREATE TABLE Usergroup(
	GroupID SERIAL PRIMARY KEY,
	Name VARCHAR(40) DEFAULT '(name empty)'
);

CREATE TABLE EmployeesInUsergroup (
	EmployeeID int NOT NULL,
	GroupID int NOT NULL,
	PRIMARY KEY(EmployeeID, GroupID),
	CONSTRAINT FK_EmployeeID FOREIGN KEY(EmployeeID)
	REFERENCES Employee(EmployeeID)
		ON DELETE CASCADE
);

CREATE TABLE Project(
	ProjectID SERIAL PRIMARY KEY,
	CustomerID int NOT NULL,
	Name VARCHAR(40) NOT NULL,
	Budget FLOAT(2) DEFAULT 0 CHECK(Budget >= 0)
);

CREATE TABLE Commission(
	ProjectID int NOT NULL,
	StartDate TIMESTAMP NOT NULL,
	Deadline TIMESTAMP NOT NULL CHECK(Deadline > StartDate),
	Started BOOLEAN  DEFAULT false,
	PRIMARY KEY(StartDate),
	CONSTRAINT FK_ProjectID FOREIGN KEY(ProjectID)
	REFERENCES Project(ProjectID)
		ON DELETE CASCADE
) PARTITION BY RANGE (StartDate);

CREATE TABLE EmployeesInProject(
	ProjectID int NOT NULL,
	EmployeeID int NOT NULL,
	PRIMARY KEY(ProjectID, EmployeeID),
	CONSTRAINT FK_EmployeeID FOREIGN KEY(EmployeeID)
	REFERENCES Employee(EmployeeID)
		ON DELETE CASCADE
);

CREATE TABLE Location(
	LocationID SERIAL PRIMARY KEY,
	Address VARCHAR(40) DEFAULT '(address missing)',
	Country VARCHAR(40) DEFAULT '(country missing)'
);

CREATE TABLE Department(
	DepartmentID SERIAL PRIMARY KEY,
	LocationID int NOT NULL,
	Name VARCHAR(40) DEFAULT '(name missing)'
);

CREATE TABLE Customer(
	CustomerID  SERIAL PRIMARY KEY,
	LocationID int NOT NULL,
	Name VARCHAR(40) DEFAULT '(name missing)',
	Email VARCHAR(40) DEFAULT '(email missing)'
);

/*Foreign keys*/
ALTER TABLE Employee 
	ADD CONSTRAINT FK_DepartmentID FOREIGN KEY(DepartmentID)
	REFERENCES Department(DepartmentID)
	ON DELETE CASCADE;
ALTER TABLE Department
	ADD CONSTRAINT FK_LocationID FOREIGN KEY(LocationID)
	REFERENCES Location(LocationID)
	ON DELETE CASCADE;
ALTER TABLE Project
	ADD CONSTRAINT FK_CustomerID FOREIGN KEY(CustomerID)
	REFERENCES Customer(CustomerID)
	ON DELETE CASCADE;	
ALTER TABLE Customer
	ADD CONSTRAINT FK_LocationID FOREIGN KEY(LocationID)
	REFERENCES Location(LocationID)
	ON DELETE CASCADE;

/*Partitions*/
CREATE TABLE projects_22_23 PARTITION OF commission
	FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2022-12-31 23:59:59');
CREATE TABLE projects_23_24 PARTITION OF commission
	FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2023-12-31 23:59:59');
CREATE TABLE projects_24_25 PARTITION OF commission
	FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2024-12-31 23:59:59');
CREATE TABLE projects_25_xx PARTITION OF commission
	DEFAULT;

CREATE TABLE employees1_50 PARTITION OF employee
	FOR VALUES FROM (1) TO (50);
CREATE TABLE employees51_100 PARTITION OF employee
	FOR VALUES FROM (51) TO (100);
CREATE TABLE employee101_150 PARTITION OF employee
	FOR VALUES FROM (101) TO (150);
CREATE TABLE employee151_X PARTITION OF employee 
	DEFAULT;

/*Triggers*/
/*startProject*/
CREATE OR REPLACE FUNCTION updateStartDate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
	IF NEW.started <> old.started AND new.started = TRUE THEN
		UPDATE commission SET startdate = now()::timestamp WHERE projectid = new.projectid;
	END IF;
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER startProject
	AFTER UPDATE ON Commission
	FOR EACH ROW
	EXECUTE PROCEDURE updateStartDate();

/*locationCountryChange*/
CREATE OR REPLACE FUNCTION changeLocationData()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
	IF NEW.country <> old.country AND new.address = old.address THEN
		UPDATE location SET address = '(address missing)' WHERE locationid = new.locationid;
		raise notice 'Remember to update address';
	END IF;
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER locationCountryChange
	AFTER UPDATE ON Location
	FOR EACH ROW
	EXECUTE PROCEDURE changeLocationData();

/*createUserGroup*/
CREATE OR REPLACE FUNCTION addUserGroup()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
	INSERT INTO Usergroup VALUES (DEFAULT,NEW.name);
	RETURN NEW;
END;
$$;
CREATE OR REPLACE TRIGGER createUserGroup
	AFTER INSERT ON Project
	FOR EACH ROW
	EXECUTE PROCEDURE addUserGroup();

/*Security*/
ALTER TABLE project ENABLE ROW LEVEL SECURITY;

CREATE ROLE Project1_employee;
CREATE ROLE Project2_employee;
CREATE ROLE Project3_employee;
CREATE ROLE Project1_manager;
CREATE ROLE Project2_manager;
CREATE ROLE Project3_manager;

GRANT SELECT ON Project TO Project1_employee;
GRANT SELECT ON Project TO Project2_employee;
GRANT SELECT ON Project TO Project3_employee;
GRANT ALL PRIVILEGES ON Project TO Project1_manager;
GRANT ALL PRIVILEGES ON Project TO Project2_manager;
GRANT ALL PRIVILEGES ON Project TO Project3_manager;

CREATE POLICY Project1_employees ON Project TO Project1_employee
	USING (projectid = 1);
CREATE POLICY Project2_employees ON Project TO Project2_employee
	USING (projectid = 2);
CREATE POLICY Project3_employees ON Project TO Project3_employee
	USING (projectid = 3);
CREATE POLICY Project1_managers ON Project TO Project1_manager
	USING (projectid = 1);
CREATE POLICY Project2_managers ON Project TO Project2_manager
	USING (projectid = 2);
CREATE POLICY Project3_managers ON Project TO Project3_manager
	USING (projectid = 3);

/*Inserts*/
INSERT INTO Location VALUES (DEFAULT,'Street 1','Finland');
INSERT INTO Location VALUES (DEFAULT,'Street 2','Finland');
INSERT INTO Location VALUES (DEFAULT,'Street 3','Finland');

INSERT INTO Department VALUES (DEFAULT,1,'HR');
INSERT INTO Department VALUES (DEFAULT,1,'Software');
INSERT INTO Department VALUES (DEFAULT,1,'Data');
INSERT INTO Department VALUES (DEFAULT,1,'ICT');
INSERT INTO Department VALUES (DEFAULT,1,'Customer Support');

INSERT INTO Customer VALUES (DEFAULT,1,'Technology LLC','technology@gmail.com');
INSERT INTO Customer VALUES (DEFAULT,1,'Funding Company','funding@gmail.com');

INSERT INTO Employee VALUES (DEFAULT, 1, 'HR Manager', 'manager1@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 1, 'Developer', 'employee1@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 2, 'Software Design Manager', 'manager2@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 2, 'Designer', 'employee2@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 3, 'Data Handling Manager', 'manager3@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 3, 'Developer', 'employee3@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 4, 'ICT Technician', 'technician1@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 4, 'Employee', 'employee4@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 5, 'Customer Support Executive', 'email1@gmail.com');
INSERT INTO Employee VALUES (DEFAULT, 5, 'Tech Support Engineer', 'employee5@gmail.com');

INSERT INTO Project VALUES (DEFAULT,1, 'Project 1', 150000.50);
INSERT INTO Commission VALUES (1,'2022-01-28','2022-12-31',TRUE);
INSERT INTO Project VALUES (DEFAULT,1, 'Project 2', 9999.99);
INSERT INTO Commission VALUES (2,'2023-01-01','2023-05-31',FALSE);
INSERT INTO Project VALUES (DEFAULT,2, 'Project 3', 5000);
INSERT INTO Commission VALUES (3,'2024-06-01','2025-9-30',FALSE);

INSERT INTO EmployeesInUsergroup VALUES(1,1);
INSERT INTO EmployeesInUsergroup VALUES(1,3);
INSERT INTO EmployeesInUsergroup VALUES(1,5);

INSERT INTO EmployeesInProject VALUES (1,4);
INSERT INTO EmployeesInProject VALUES (1,5);
INSERT INTO EmployeesInProject VALUES (1,6);
INSERT INTO EmployeesInProject VALUES (1,7);
INSERT INTO EmployeesInProject VALUES (1,8);
INSERT INTO EmployeesInProject VALUES (2,1);
INSERT INTO EmployeesInProject VALUES (2,2);
INSERT INTO EmployeesInProject VALUES (2,5);
INSERT INTO EmployeesInProject VALUES (2,6);
INSERT INTO EmployeesInProject VALUES (2,9);
INSERT INTO EmployeesInProject VALUES (2,10);
INSERT INTO EmployeesInProject VALUES (3,1);
INSERT INTO EmployeesInProject VALUES (3,2);
INSERT INTO EmployeesInProject VALUES (3,5);
INSERT INTO EmployeesInProject VALUES (3,6);
INSERT INTO EmployeesInProject VALUES (3,9);
INSERT INTO EmployeesInProject VALUES (3,10);

INSERT INTO Role VALUES (1, 'Manager', 'Manages the company and its employees');
INSERT INTO Role VALUES (2, 'Developer', 'Works on the project');
INSERT INTO Role VALUES (3, 'Designer', 'Works on the project design');
INSERT INTO Role VALUES (4, 'Employee', 'Does various jobs in the company');

INSERT INTO EmployeeRoles VALUES (1,1);
INSERT INTO EmployeeRoles VALUES (2,2);
INSERT INTO EmployeeRoles VALUES (3,1);
INSERT INTO EmployeeRoles VALUES (4,3);
INSERT INTO EmployeeRoles VALUES (5,1);
INSERT INTO EmployeeRoles VALUES (6,2);
INSERT INTO EmployeeRoles VALUES (7,4);
INSERT INTO EmployeeRoles VALUES (8,4);
INSERT INTO EmployeeRoles VALUES (9,1);
INSERT INTO EmployeeRoles VALUES (10,4);