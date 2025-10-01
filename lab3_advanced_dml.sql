-- Laboratory Work #3 - Advanced DML operations

-- Part A: Database and Table Setup

-- 1) Create database (run once in a session that can create DBs)
CREATE DATABASE IF NOT EXISTS advanced_lab;
-- After creating the DB, connect to it (in psql use: \c advanced_lab)

\-- ---------------------------------------------------------
-- The following CREATE TABLE statements assume you are connected
-- to the advanced_lab database.
\-- ---------------------------------------------------------

-- Table: employees
CREATE TABLE IF NOT EXISTS employees (
    emp_id        SERIAL PRIMARY KEY,
    first_name    VARCHAR(50) NOT NULL,
    last_name     VARCHAR(50) NOT NULL,
    department    VARCHAR(100), -- stored as department name (per lab spec)
    salary        INTEGER DEFAULT 50000,
    hire_date     DATE DEFAULT CURRENT_DATE,
    status        VARCHAR(20) DEFAULT 'Active'
);

-- Table: departments
CREATE TABLE IF NOT EXISTS departments (
    dept_id   SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    budget    INTEGER DEFAULT 0,
    manager_id INTEGER,
    CONSTRAINT fk_manager_employee FOREIGN KEY (manager_id) REFERENCES employees(emp_id) ON DELETE SET NULL
);

-- Table: projects
CREATE TABLE IF NOT EXISTS projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR(150) NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id) ON DELETE SET NULL,
    start_date DATE,
    end_date DATE,
    budget INTEGER DEFAULT 0
);

-- Part B: Advanced INSERT Operations (sample data included)

-- 2) INSERT with column specification (only some columns)
INSERT INTO employees (emp_id, first_name, last_name, department)
VALUES (DEFAULT, 'Aida', 'Nurlybek', 'IT');

-- 3) INSERT with DEFAULT values for salary and status
INSERT INTO employees (first_name, last_name, hire_date)
VALUES ('Bulat', 'Suleimen', CURRENT_DATE);
-- salary and status will use DEFAULT (50000 and 'Active')

-- 4) INSERT multiple rows in single statement into departments
INSERT INTO departments (dept_name, budget)
VALUES
  ('IT', 120000),
  ('Sales', 90000),
  ('HR', 50000)
ON CONFLICT (dept_name) DO NOTHING; -- safe re-run

-- 5) INSERT with expressions: hire_date = current_date, salary = 50000 * 1.1
INSERT INTO employees (first_name, last_name, department, hire_date, salary)
VALUES ('Dana', 'Ibragim', 'IT', CURRENT_DATE, CAST(50000 * 1.1 AS INTEGER));

-- 6) INSERT FROM SELECT (subquery) into temporary table
CREATE TEMP TABLE temp_employees AS
SELECT * FROM employees WHERE department = 'IT';

-- Part C: Complex UPDATE Operations

-- 7) Increase all employee salaries by 10%
UPDATE employees
SET salary = CAST(ROUND(salary * 1.10) AS INTEGER);

-- 8) Update employee status to 'Senior' where salary > 60000 AND hire_date < '2020-01-01'
UPDATE employees
SET status = 'Senior'
WHERE salary > 60000 AND hire_date < DATE '2020-01-01';

-- 9) UPDATE using CASE expression to set department label based on salary ranges
-- NOTE: this overwrites department names with category labels per the exercise.
UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN 'Management'
    WHEN salary BETWEEN 50000 AND 80000 THEN 'Senior'
    ELSE 'Junior'
END;

-- 10) UPDATE with DEFAULT: set department to DEFAULT for employees with status = 'Inactive'
-- For this table, department has no declared DEFAULT, so we'll use NULL as the default
-- (lab text said 'DEFAULT' — here we interpret it as setting department to NULL/default state).
UPDATE employees
SET department = DEFAULT
WHERE status = 'Inactive';

-- 11) UPDATE with subquery: set departments.budget = 20% higher than average salary
-- If department names in employees match departments.dept_name
UPDATE departments d
SET budget = CAST(ROUND((
    SELECT COALESCE(AVG(e.salary), 0) * 1.20
    FROM employees e
    WHERE e.department = d.dept_name
) ) AS INTEGER);

-- 12) UPDATE multiple columns in single statement for Sales department
UPDATE employees
SET salary = CAST(ROUND(salary * 1.15) AS INTEGER),
    status = 'Promoted'
WHERE department = 'Sales';

-- Part D: Advanced DELETE Operations

-- 13) DELETE with simple WHERE: delete employees with status = 'Terminated'
DELETE FROM employees WHERE status = 'Terminated';

-- 14) DELETE with complex WHERE clause
DELETE FROM employees
WHERE salary < 40000
  AND hire_date > DATE '2023-01-01'
  AND department IS NULL;

-- 15) DELETE departments where dept_id NOT IN (distinct departments in employees)
DELETE FROM departments
WHERE dept_id NOT IN (
    SELECT DISTINCT (d2.dept_id) FROM departments d2 WHERE d2.dept_name IN (
        SELECT DISTINCT department FROM employees WHERE department IS NOT NULL
    )
);
-- The above preserves departments whose dept_name appears in employees.department.
-- If your schema used dept_id in employees, this would be simpler.

-- 16) DELETE with RETURNING clause: delete old projects (end_date < '2023-01-01') and return deleted rows
-- This statement will return rows when run interactively
DELETE FROM projects
WHERE end_date < DATE '2023-01-01'
RETURNING *;

-- Part E: Operations with NULL Values

-- 17) INSERT with NULL values
INSERT INTO employees (first_name, last_name, salary, department, hire_date)
VALUES ('Ermek', 'Zhanibek', NULL, NULL, CURRENT_DATE);

-- 18) UPDATE NULL handling: set department = 'Unassigned' where department IS NULL
UPDATE employees
SET department = 'Unassigned'
WHERE department IS NULL;

-- 19) DELETE with NULL conditions: delete employees where salary IS NULL OR department IS NULL
DELETE FROM employees WHERE salary IS NULL OR department IS NULL;

-- Part F: RETURNING Clause Operations

-- 20) INSERT with RETURNING: insert new employee and return generated emp_id and full name
-- Example of how to capture/see values in an interactive session
INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Gulnar', 'Kairat', 'HR', 55000, CURRENT_DATE)
RETURNING emp_id, (first_name || ' ' || last_name) AS full_name;

-- 21) UPDATE with RETURNING: increase salary by 5000 for employees in 'IT' and return emp_id, old and new salary
-- We use a CTE to capture old salary for returning both old and new values
WITH updated AS (
    UPDATE employees
    SET salary = salary + 5000
    WHERE department = 'IT'
    RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary
)
SELECT * FROM updated;

-- 22) DELETE with RETURNING all columns: delete employees hired before 2020-01-01 and return all columns
DELETE FROM employees
WHERE hire_date < DATE '2020-01-01'
RETURNING *;

-- Part G: Advanced DML Patterns

-- 23) Conditional INSERT: insert only if not exists (same first_name and last_name)
INSERT INTO employees (first_name, last_name, department, salary, hire_date)
SELECT 'Ilya', 'Orlov', 'Sales', 48000, CURRENT_DATE
WHERE NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.first_name = 'Ilya' AND e.last_name = 'Orlov'
);

-- 24) UPDATE with JOIN logic using subqueries: adjust salary based on department budget
-- If department budget > 100000 increase by 10% else by 5%
UPDATE employees e
SET salary = CAST(ROUND(
    salary * (
        CASE
            WHEN (SELECT budget FROM departments d WHERE d.dept_name = e.department) > 100000 THEN 1.10
            ELSE 1.05
        END
    )
) AS INTEGER)
WHERE e.department IS NOT NULL;

-- 25) Bulk operations: insert 5 employees in single statement, then update their salaries +10% in single UPDATE
WITH new_emps AS (
    INSERT INTO employees (first_name, last_name, department, salary, hire_date)
    VALUES
      ('Jamilya', 'Aman', 'Sales', 42000, CURRENT_DATE),
      ('Karim', 'Tulegen', 'Sales', 43000, CURRENT_DATE),
      ('Leila', 'Nurzhan', 'Sales', 41000, CURRENT_DATE),
      ('Murat', 'Osman', 'Sales', 44000, CURRENT_DATE),
      ('Nurlan', 'Aibek', 'Sales', 45000, CURRENT_DATE)
    RETURNING emp_id
)
-- Now update all their salaries to be 10% higher using the emp_ids captured above
UPDATE employees
SET salary = CAST(ROUND(salary * 1.10) AS INTEGER)
WHERE emp_id IN (SELECT emp_id FROM new_emps);

-- 26) Data migration simulation: create employee_archive, move inactive employees, delete from original
CREATE TABLE IF NOT EXISTS employee_archive (LIKE employees INCLUDING ALL);

INSERT INTO employee_archive
SELECT * FROM employees WHERE status = 'Inactive';

DELETE FROM employees WHERE status = 'Inactive';

-- 27) Complex business logic: extend project end_date by 30 days for projects where
-- budget > 50000 AND associated department has more than 3 employees
UPDATE projects p
SET end_date = p.end_date + INTERVAL '30 days'
FROM departments d
WHERE p.dept_id = d.dept_id
  AND p.budget > 50000
  AND (
      SELECT COUNT(*) FROM employees e WHERE e.department = d.dept_name
  ) > 3;
