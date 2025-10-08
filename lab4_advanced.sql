-- Task 1.1: select all employees with full name, department and salary
-- Output: employee_id, full_name, department, salary
SELECT employee_id,
       first_name || ' ' || last_name AS full_name,
       department,
       salary
FROM employees;

-- Task 1.2: distinct departments
SELECT DISTINCT department
FROM employees;

-- Task 1.3: projects with budget_category
SELECT project_id,
       project_name,
       budget,
       CASE
           WHEN budget > 150000 THEN 'Large'
           WHEN budget BETWEEN 100000 AND 150000 THEN 'Medium'
           ELSE 'Small'
       END AS budget_category
FROM projects;

-- Task 1.4: employee names and emails with COALESCE
SELECT employee_id,
       first_name || ' ' || last_name AS full_name,
       COALESCE(email, 'No email provided') AS email
FROM employees;

-- Task 2.1: employees hired after 2020-01-01
SELECT employee_id, first_name, last_name, hire_date
FROM employees
WHERE hire_date > DATE '2020-01-01';

-- Task 2.2: employees with salary between 60000 and 70000
SELECT employee_id, first_name, last_name, salary
FROM employees
WHERE salary BETWEEN 60000 AND 70000;

-- Task 2.3: employees whose last name starts with 'S' or 'J'
SELECT employee_id, first_name, last_name
FROM employees
WHERE last_name LIKE 'S%' OR last_name LIKE 'J%';

-- Task 2.4: employees who have a manager and work in IT
SELECT employee_id, first_name, last_name, manager_id, department
FROM employees
WHERE manager_id IS NOT NULL AND department = 'IT';

-- Task 3.1: employee names in uppercase, length of last names, first 3 chars of email
SELECT employee_id,
       UPPER(first_name || ' ' || last_name) AS name_upper,
       CHAR_LENGTH(last_name) AS last_name_length,
       CASE WHEN email IS NULL THEN NULL ELSE substring(email FROM 1 FOR 3) END AS email_first3
FROM employees;

-- Task 3.2: annual salary, monthly salary (rounded), 10% raise amount
SELECT employee_id,
       first_name || ' ' || last_name AS full_name,
       salary AS monthly_salary_current,
       salary * 12 AS annual_salary,
       ROUND(salary::numeric / 12.0, 2) AS monthly_salary,
       ROUND(salary * 0.10, 2) AS raise_10_percent
FROM employees;

-- Task 3.3: formatted project string using format()
SELECT project_id,
       format('Project: %s - Budget: $%s - Status: %s', project_name, budget, status) AS project_info
FROM projects;

-- Task 3.4: how many years each employee has been with the company
SELECT employee_id,
       first_name || ' ' || last_name AS full_name,
       hire_date,
       DATE_PART('year', AGE(CURRENT_DATE, hire_date))::int AS years_with_company
FROM employees;

-- Task 4.1: average salary for each department
SELECT department,
       ROUND(AVG(salary)::numeric, 2) AS avg_salary
FROM employees
GROUP BY department;

-- Task 4.2: total hours worked on each project (include project name)
SELECT p.project_id,
       p.project_name,
       SUM(a.hours_worked) AS total_hours
FROM projects p
LEFT JOIN assignments a ON p.project_id = a.project_id
GROUP BY p.project_id, p.project_name;

-- Task 4.3: count number of employees in each department, show departments with more than 1 employee
SELECT department,
       COUNT(*) AS employee_count
FROM employees
GROUP BY department
HAVING COUNT(*) > 1;

-- Task 4.4: max and min salary and total payroll
SELECT MAX(salary) AS max_salary,
       MIN(salary) AS min_salary,
       SUM(salary) AS total_payroll
FROM employees;

-- Task 5.1: UNION of employees with salary > 65000 and employees hired after 2020-01-01
-- Display employee_id, full name, salary
SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE salary > 65000
UNION
SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE hire_date > DATE '2020-01-01';

-- Task 5.2: INTERSECT to find employees who work in IT AND have salary greater than 65000
SELECT employee_id, first_name || ' ' || last_name AS full_name, department, salary
FROM employees
WHERE department = 'IT'
INTERSECT
SELECT employee_id, first_name || ' ' || last_name AS full_name, department, salary
FROM employees
WHERE salary > 65000;

-- Task 5.3: EXCEPT to find all employees who are NOT assigned to any projects
SELECT employee_id, first_name, last_name
FROM employees
EXCEPT
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
JOIN assignments a ON e.employee_id = a.employee_id;

-- Task 6.1: EXISTS to find employees who have at least one project assignment
SELECT e.employee_id, e.first_name || ' ' || e.last_name AS full_name
FROM employees e
WHERE EXISTS (
    SELECT 1 FROM assignments a WHERE a.employee_id = e.employee_id
);

-- Task 6.2: IN with subquery to find employees working on projects with status 'Active'
SELECT DISTINCT e.employee_id, e.first_name, e.last_name
FROM employees e
WHERE e.employee_id IN (
    SELECT a.employee_id
    FROM assignments a
    JOIN projects p ON a.project_id = p.project_id
    WHERE p.status = 'Active'
);

-- Task 6.3: ANY to find employees whose salary is greater than ANY employee in the Sales department
SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
FROM employees
WHERE salary > ANY (
    SELECT salary FROM employees WHERE department = 'Sales'
);

-- Task 7.1: Employee name, department, average hours across assignments, and rank within department by salary
-- Using window function for rank
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       e.department,
       ROUND(AVG(a.hours_worked)::numeric, 2) AS avg_hours_worked,
       RANK() OVER (PARTITION BY e.department ORDER BY e.salary DESC) AS dept_salary_rank
FROM employees e
LEFT JOIN assignments a ON e.employee_id = a.employee_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.department, e.salary
ORDER BY e.department, dept_salary_rank;

-- Task 7.2: projects where total hours worked exceeds 150 hours. Display project name, total hours, and number of employees assigned
SELECT p.project_id,
       p.project_name,
       SUM(a.hours_worked) AS total_hours,
       COUNT(DISTINCT a.employee_id) AS employees_assigned
FROM projects p
JOIN assignments a ON p.project_id = a.project_id
GROUP BY p.project_id, p.project_name
HAVING SUM(a.hours_worked) > 150;

-- Task 7.3: departments with total number of employees, average salary, highest paid employee name. Use GREATEST and LEAST somewhere.
WITH dept_stats AS (
    SELECT department,
           COUNT(*) AS total_employees,
           AVG(salary) AS avg_salary,
           MAX(salary) AS max_salary,
           MIN(salary) AS min_salary
    FROM employees
    GROUP BY department
)
SELECT ds.department,
       ds.total_employees,
       ROUND(ds.avg_salary::numeric, 2) AS avg_salary,
       -- get name of employee(s) who have the max salary in the department
       (SELECT first_name || ' ' || last_name
        FROM employees e
        WHERE e.department = ds.department AND e.salary = ds.max_salary
        LIMIT 1) AS highest_paid_employee,
       -- Demonstrate GREATEST and LEAST (compare avg and max for example)
       GREATEST(ds.max_salary, ds.avg_salary) AS greatest_of_max_and_avg,
       LEAST(ds.min_salary, ds.avg_salary) AS least_of_min_and_avg
FROM dept_stats ds;
