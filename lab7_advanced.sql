-- 0. Basic setup: create tables if they don't exist and insert sample data
CREATE TABLE IF NOT EXISTS departments (
  dept_id   INT PRIMARY KEY,
  dept_name TEXT NOT NULL,
  location  TEXT
);

CREATE TABLE IF NOT EXISTS employees (
  emp_id   INT PRIMARY KEY,
  emp_name TEXT NOT NULL,
  dept_id  INT,
  salary   NUMERIC(12,2),
  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS projects (
  project_id   INT PRIMARY KEY,
  project_name TEXT NOT NULL,
  budget       NUMERIC(14,2),
  dept_id      INT,
  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- sample departments
INSERT INTO departments (dept_id, dept_name, location) VALUES
  (101, 'IT', 'Almaty'),
  (102, 'HR', 'Astana'),
  (103, 'Finance', 'Shymkent')
ON CONFLICT (dept_id) DO NOTHING;

-- sample employees
INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
  (1, 'John Smith', 101, 50000),
  (2, 'Jane Doe',   101, 62000),
  (3, 'Tom Brown',  NULL, 48000),
  (4, 'Sara Khan',  102, 54000),
  (5, 'Michael Li', 103, 80000)
ON CONFLICT (emp_id) DO NOTHING;

-- sample projects
INSERT INTO projects (project_id, project_name, budget, dept_id) VALUES
  (201, 'Platform Upgrade', 120000, 101),
  (202, 'Recruitment Drive', 20000, 102),
  (203, 'Annual Audit', 90000, 103)
ON CONFLICT (project_id) DO NOTHING;

-- Part 2: Creating basic views
CREATE OR REPLACE VIEW employee_details AS
SELECT e.emp_id, e.emp_name AS employee_name, e.salary, d.dept_name, d.location
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.dept_id IS NOT NULL;

CREATE OR REPLACE VIEW dept_statistics AS
SELECT d.dept_id, d.dept_name,
       COUNT(e.emp_id) AS employee_count,
       ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
       COALESCE(MAX(e.salary),0) AS max_salary,
       COALESCE(MIN(e.salary),0) AS min_salary
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;

CREATE OR REPLACE VIEW project_overview AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, d.location,
       COALESCE((SELECT COUNT(*) FROM employees e2 WHERE e2.dept_id = d.dept_id),0) AS team_size
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id;

CREATE OR REPLACE VIEW high_earners AS
SELECT emp_id, emp_name, salary, dept_id
FROM employees
WHERE salary > 55000;

-- Part 3: Modifying and managing views
-- 3.1 Replace employee_details to include salary grade
CREATE OR REPLACE VIEW employee_details AS
SELECT e.emp_id, e.emp_name AS employee_name, e.salary, d.dept_name, d.location,
       CASE
         WHEN e.salary > 60000 THEN 'High'
         WHEN e.salary > 50000 THEN 'Medium'
         ELSE 'Standard'
       END AS salary_grade
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.dept_id IS NOT NULL;

-- 3.2 Rename high_earners -> top_performers
DROP VIEW IF EXISTS top_performers;
CREATE OR REPLACE VIEW top_performers AS
SELECT emp_id, emp_name, salary, dept_id FROM high_earners;
DROP VIEW IF EXISTS high_earners;

-- 3.3 Temporary view and drop
CREATE TEMP VIEW temp_view AS SELECT emp_id, emp_name, salary FROM employees WHERE salary < 50000;
DROP VIEW IF EXISTS temp_view;

-- Part 4: Updatable views
CREATE OR REPLACE VIEW employee_salaries AS
SELECT emp_id, emp_name, dept_id, salary FROM employees;

-- Update John Smith's salary through the view
UPDATE employee_salaries SET salary = 52000 WHERE emp_name = 'John Smith';

-- Insert through the view (should succeed because view is simple)
INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary) VALUES (6, 'Alice Johnson', 102, 58000)
ON CONFLICT (emp_id) DO NOTHING;

-- View with CHECK OPTION
CREATE OR REPLACE VIEW it_employees AS
SELECT emp_id, emp_name, dept_id, salary FROM employees WHERE dept_id = 101
WITH LOCAL CHECK OPTION;

-- Try inserting an employee from another department into it_employees (should raise error)
DO $$
BEGIN
  BEGIN
    INSERT INTO it_employees (emp_id, emp_name, dept_id, salary) VALUES (7, 'Bob Wilson', 103, 60000);
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Expected failure inserting into it_employees with wrong dept (%%). Error: %%', 103, SQLERRM;
  END;
END$$;

-- Part 5: Materialized views
CREATE MATERIALIZED VIEW IF NOT EXISTS dept_summary_mv AS
SELECT d.dept_id, d.dept_name,
       COUNT(e.emp_id) AS total_employees,
       COALESCE(SUM(e.salary),0) AS total_salaries,
       COALESCE(COUNT(p.project_id),0) AS total_projects,
       COALESCE(SUM(p.budget),0) AS total_project_budget
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
WITH NO DATA;

-- Refresh with data initially
REFRESH MATERIALIZED VIEW dept_summary_mv;

-- Insert new employee Charlie Brown and show difference before/after refresh
INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES (8, 'Charlie Brown', 101, 54000)
ON CONFLICT (emp_id) DO NOTHING;

-- demonstrate refresh (select before and after programmatically)
-- (select before refresh)
-- Note: these selects are left here so user can run them manually to observe differences
-- SELECT * FROM dept_summary_mv ORDER BY total_employees DESC;

-- create unique index to allow concurrent refresh
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid WHERE c.relname = 'dept_summary_mv_dept_id_idx') THEN
    CREATE UNIQUE INDEX IF NOT EXISTS dept_summary_mv_dept_id_idx ON dept_summary_mv (dept_id);
  END IF;
END$$;

-- concurrent refresh (may require superuser if concurrent is restricted)
-- To avoid blocking reads you can use:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;
-- but only if a unique index exists and there are no other concurrent refreshes.

-- Materialized view with NO DATA
CREATE MATERIALIZED VIEW IF NOT EXISTS project_stats_mv WITH NO DATA AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, COUNT(e.emp_id) AS assigned_employees
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
LEFT JOIN employees e ON e.dept_id = p.dept_id
GROUP BY p.project_id, p.project_name, p.budget, d.dept_name;

-- Querying project_stats_mv now returns zero rows until refreshed; refresh to populate
REFRESH MATERIALIZED VIEW project_stats_mv;

-- Part 6: Database roles
-- Create roles carefully (only create if not exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyst') THEN
    EXECUTE 'CREATE ROLE analyst NOINHERIT';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'data_viewer') THEN
    EXECUTE 'CREATE ROLE data_viewer LOGIN PASSWORD ''viewer123''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'report_user') THEN
    EXECUTE 'CREATE ROLE report_user LOGIN PASSWORD ''report456''';
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_creator') THEN
    EXECUTE 'CREATE ROLE db_creator LOGIN PASSWORD ''creator789'' CREATEDB';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'user_manager') THEN
    EXECUTE 'CREATE ROLE user_manager LOGIN PASSWORD ''manager101'' CREATEROLE';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_user') THEN
    EXECUTE 'CREATE ROLE admin_user LOGIN PASSWORD ''admin999'' SUPERUSER';
  END IF;
END$$;

-- Grants
GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

-- Group roles and users
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hr_team') THEN
    EXECUTE 'CREATE ROLE hr_team NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finance_team') THEN
    EXECUTE 'CREATE ROLE finance_team NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'it_team') THEN
    EXECUTE 'CREATE ROLE it_team NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hr_user1') THEN
    EXECUTE 'CREATE ROLE hr_user1 LOGIN PASSWORD ''hr001''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hr_user2') THEN
    EXECUTE 'CREATE ROLE hr_user2 LOGIN PASSWORD ''hr002''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'finance_user1') THEN
    EXECUTE 'CREATE ROLE finance_user1 LOGIN PASSWORD ''fin001''';
  END IF;
END$$;

-- Assign members
GRANT hr_team TO hr_user1;
GRANT hr_team TO hr_user2;
GRANT finance_team TO finance_user1;

GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

-- Revoke operations
REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

-- Modify role attributes
ALTER ROLE analyst WITH LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager WITH SUPERUSER;
ALTER ROLE analyst WITH PASSWORD NULL;
ALTER ROLE data_viewer WITH CONNECTION LIMIT 5;

-- Part 7: Advanced role management
-- Role hierarchy
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'read_only') THEN
    EXECUTE 'CREATE ROLE read_only NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'junior_analyst') THEN
    EXECUTE 'CREATE ROLE junior_analyst LOGIN PASSWORD ''junior123''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'senior_analyst') THEN
    EXECUTE 'CREATE ROLE senior_analyst LOGIN PASSWORD ''senior123''';
  END IF;
END$$;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;
GRANT read_only TO junior_analyst;
GRANT read_only TO senior_analyst;
GRANT INSERT, UPDATE ON employees TO senior_analyst;

-- Object ownership
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'project_manager') THEN
    EXECUTE 'CREATE ROLE project_manager LOGIN PASSWORD ''pm123''';
  END IF;
END$$;

ALTER VIEW IF EXISTS dept_statistics OWNER TO project_manager;
ALTER TABLE IF EXISTS projects OWNER TO project_manager;

-- Reassign and drop roles example
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'temp_owner') THEN
    EXECUTE 'CREATE ROLE temp_owner LOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_tables WHERE tablename = 'temp_table') THEN
    EXECUTE 'CREATE TABLE temp_table (id INT)';
  END IF;
  EXECUTE 'ALTER TABLE temp_table OWNER TO temp_owner';
  -- Reassign to postgres and drop
  EXECUTE 'REASSIGN OWNED BY temp_owner TO postgres';
  EXECUTE 'DROP OWNED BY temp_owner';
  EXECUTE 'DROP ROLE IF EXISTS temp_owner';
END$$;

-- Row-level restricted views
CREATE OR REPLACE VIEW hr_employee_view AS
SELECT emp_id, emp_name, dept_id, salary FROM employees WHERE dept_id = 102;
GRANT SELECT ON hr_employee_view TO hr_team;

CREATE OR REPLACE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary FROM employees;
GRANT SELECT ON finance_employee_view TO finance_team;

-- Part 8: Practical scenarios
CREATE OR REPLACE VIEW dept_dashboard AS
SELECT d.dept_id, d.dept_name, d.location,
       COUNT(e.emp_id) AS employee_count,
       ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
       COALESCE(SUM(CASE WHEN p.project_id IS NOT NULL THEN 1 ELSE 0 END),0) AS active_projects,
       COALESCE(SUM(p.budget),0) AS total_project_budget,
       CASE WHEN COUNT(e.emp_id) = 0 THEN 0
            ELSE ROUND((COALESCE(SUM(p.budget),0) / COUNT(e.emp_id))::numeric,2)
       END AS budget_per_employee
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects p ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name, d.location;

-- Audit view
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW high_budget_projects AS
SELECT p.project_id, p.project_name, p.budget, d.dept_name, p.created_date,
       CASE
         WHEN p.budget > 150000 THEN 'Critical Review Required'
         WHEN p.budget > 100000 THEN 'Management Approval Needed'
         ELSE 'Standard Process'
       END AS approval_status
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
WHERE p.budget > 75000;

-- Access control system: roles and users
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'viewer_role') THEN
    EXECUTE 'CREATE ROLE viewer_role NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'entry_role') THEN
    EXECUTE 'CREATE ROLE entry_role NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analyst_role') THEN
    EXECUTE 'CREATE ROLE analyst_role NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'manager_role') THEN
    EXECUTE 'CREATE ROLE manager_role NOLOGIN';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'alice') THEN
    EXECUTE 'CREATE ROLE alice LOGIN PASSWORD ''alice123''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bob') THEN
    EXECUTE 'CREATE ROLE bob LOGIN PASSWORD ''bob123''';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'charlie') THEN
    EXECUTE 'CREATE ROLE charlie LOGIN PASSWORD ''charlie123''';
  END IF;
END$$;

GRANT SELECT ON ALL TABLES, ALL SEQUENCES IN SCHEMA public TO viewer_role;
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees, projects TO entry_role;
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees, projects TO analyst_role;
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;

GRANT viewer_role TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;


-- Helpful selects (uncomment to inspect results):
-- SELECT * FROM employee_details;
-- SELECT * FROM dept_statistics;
-- SELECT * FROM project_overview;
-- SELECT * FROM top_performers;
-- SELECT * FROM employee_salaries;
-- SELECT * FROM it_employees;
-- SELECT * FROM dept_summary_mv;
-- SELECT * FROM project_stats_mv;
-- SELECT * FROM dept_dashboard;
-- SELECT * FROM high_budget_projects;