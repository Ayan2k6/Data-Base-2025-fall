-- Удаляем старые таблицы (чтобы скрипт можно было запускать несколько раз)
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;


-- Часть 1: Создание таблиц

CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary NUMERIC(10,2)
);

CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);

CREATE TABLE projects (
    project_id INT PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id INT,
    budget NUMERIC(10,2)
);


-- Часть 1.2: Вставка данных

INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
(1, 'John Smith', 101, 50000),
(2, 'Jane Doe', 102, 60000),
(3, 'Mike Johnson', 101, 55000),
(4, 'Sarah Williams', 103, 65000),
(5, 'Tom Brown', NULL, 45000);

INSERT INTO departments (dept_id, dept_name, location) VALUES
(101, 'IT', 'Building A'),
(102, 'HR', 'Building B'),
(103, 'Finance', 'Building C'),
(104, 'Marketing', 'Building D');

INSERT INTO projects (project_id, project_name, dept_id, budget) VALUES
(1, 'Website Redesign', 101, 100000),
(2, 'Employee Training', 102, 50000),
(3, 'Budget Analysis', 103, 75000),
(4, 'Cloud Migration', 101, 150000),
(5, 'AI Research', NULL, 200000);


-- Part 2: CROSS JOIN Exercises


-- Exercise 2.1: все возможные комбинации employees × departments
-- Ожидаемое количество строк: N × M = 5 (employees) × 4 (departments) = 20
SELECT e.emp_name, d.dept_name
FROM employees e
CROSS JOIN departments d;
-- Альтернативные синтаксисы:
-- FROM employees, departments;
-- INNER JOIN departments ON TRUE;

-- Exercise 2.3: schedule employees × projects (полезно для availability matrix)
-- Ожидаемое количество строк: 5 × 5 = 25
SELECT e.emp_name, p.project_name
FROM employees e
CROSS JOIN projects p
ORDER BY e.emp_id, p.project_id;



-- Part 3: INNER JOIN Exercises


-- Exercise 3.1: сотрудники с названиями отделов (только те, у кого dept_id не NULL и совпадает)
-- Ожидается 4 строки: John(101), Jane(102), Mike(101), Sarah(103). Tom Brown не включён (dept_id IS NULL).
SELECT e.emp_name, d.dept_name, d.location
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id;

-- Exercise 3.2: USING (разница: колонка dept_id будет показана только однажды)
SELECT emp_name, dept_name, location
FROM employees
INNER JOIN departments USING (dept_id);

-- Exercise 3.3: NATURAL INNER JOIN
-- NATURAL автоматически соединит по одноимённым колонкам (в нашем случае dept_id).
-- Результат похож на USING: dept_id не повторяется в выводе.
SELECT emp_name, dept_name, location
FROM employees
NATURAL JOIN departments;

-- Exercise 3.4: join всех трёх таблиц: employee, department, project
-- Показывает имя сотрудника, отдел, проект — только там, где есть соответствие dept_id между всеми таблицами
SELECT e.emp_name, d.dept_name, p.project_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
INNER JOIN projects p ON d.dept_id = p.dept_id
ORDER BY e.emp_name, p.project_name;
-- Ожидаемый подсчёт (по вставленным данным): John(2 проекта), Mike(2), Jane(1), Sarah(1) => 6 строк



-- Part 4: LEFT JOIN Exercises


-- Exercise 4.1: все сотрудники и их отделы (включая тех, у кого dept_id NULL)
SELECT e.emp_name,
       e.dept_id AS emp_dept,
       d.dept_id AS dept_dept,
       d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id;
-- Tom Brown будет представлен строкой с NULL в колонках отдела (dept_dept, dept_name NULL).

-- Exercise 4.2: тот же запрос, используя USING
SELECT emp_name, dept_id, dept_name
FROM employees
LEFT JOIN departments USING (dept_id);

-- Exercise 4.3: найти сотрудников без отдела
SELECT e.emp_name, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;
-- Ожидается: Tom Brown

-- Exercise 4.4: все департаменты и количество сотрудников (включая 0)
SELECT d.dept_name, COUNT(e.emp_id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;
-- Ожидаемые значения: IT=2, HR=1, Finance=1, Marketing=0



-- Part 5: RIGHT JOIN Exercises


-- Exercise 5.1: все департаменты с их сотрудниками (включая департаменты без сотрудников)
SELECT e.emp_name, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
ORDER BY d.dept_name, e.emp_name;

-- Exercise 5.2: тот же результат через LEFT JOIN (переставляем таблицы)
SELECT e.emp_name, d.dept_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
ORDER BY d.dept_name, e.emp_name;

-- Exercise 5.3: департаменты без сотрудников
SELECT d.dept_name, d.location
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;
-- Ожидается: Marketing (dept_id 104)



-- Part 6: FULL JOIN Exercises


-- Exercise 6.1: все сотрудники и все департаменты (NULL там, где нет совпадения)
SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id
ORDER BY COALESCE(d.dept_id, e.dept_id), e.emp_name;
-- NULL слева (e.*) означает департамент без сотрудников (dept 104);
-- NULL справа (d.*) означает сотрудник без отдела (Tom Brown).

-- Exercise 6.2: все департаменты и все проекты
SELECT d.dept_name, p.project_name, p.budget
FROM departments d
FULL JOIN projects p ON d.dept_id = p.dept_id
ORDER BY d.dept_name NULLS LAST, p.project_name;
-- Проекты с NULL dept_id (AI Research) тоже появятся (отдельная строка).

-- Exercise 6.3: найти "осиротевшие" записи (employees без dept и dept без emp)
SELECT 
    CASE 
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employee without department'
        ELSE 'Matched'
    END AS record_status,
    e.emp_name,
    d.dept_name
FROM employees e
FULL JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL OR d.dept_id IS NULL;


-- Part 7: ON vs WHERE Clause


-- Query 1: фильтр в ON (LEFT JOIN)
SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id AND d.location = 'Building A'
ORDER BY e.emp_name;
-- Результат: ВСЕ сотрудники входят в результат; department будет присоединён только если location='Building A'.

-- Query 2: фильтр в WHERE (LEFT JOIN + WHERE)
SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.location = 'Building A'
ORDER BY e.emp_name;
-- Результат: фильтр WHERE отбрасывает строки, где d.location != 'Building A' или d IS NULL.
-- Следствие: в Query2 могут отсутствовать сотрудники без отдела (они отфильтруются), в Query1 они останутся с NULL для dept.

-- С ON vs WHERE с INNER JOIN — разницы нет, потому что INNER JOIN уже требует совпадение; фильтрация до или после соединения даст одинаковую выборку.


-- Part 8: Complex JOIN Scenarios


-- Exercise 8.1: комбинированный запрос: все департаменты + (если есть) сотрудники + (если есть) проекты
SELECT 
    d.dept_name,
    e.emp_name,
    e.salary,
    p.project_name,
    p.budget
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p ON d.dept_id = p.dept_id
ORDER BY d.dept_name, e.emp_name;

-- Exercise 8.2: Self join — добавим manager_id и примерные обновления
ALTER TABLE employees ADD COLUMN IF NOT EXISTS manager_id INT;

-- Присваиваем sample manager_id (как в PDF)
UPDATE employees SET manager_id = 3 WHERE emp_id = 1;
UPDATE employees SET manager_id = 3 WHERE emp_id = 2;
UPDATE employees SET manager_id = NULL WHERE emp_id = 3;
UPDATE employees SET manager_id = 3 WHERE emp_id = 4;
UPDATE employees SET manager_id = 3 WHERE emp_id = 5;

-- Self-join: employee + manager
SELECT 
    e.emp_name AS employee,
    m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id
ORDER BY e.emp_id;

-- Exercise 8.3: Join с подзапросом — департаменты со средней зарплатой > 50000
SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM departments d
INNER JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING AVG(e.salary) > 50000;
-- Ожидаемые строки: IT (52500), HR (60000), Finance (65000).



-- Lab Questions — ответы (коротко)

/*
1. Разница между INNER JOIN и LEFT JOIN:
   - INNER JOIN возвращает только строки с совпадающими ключами в обеих таблицах.
   - LEFT JOIN возвращает все строки из левой таблицы и соответствующие (если есть) из правой; 
     если соответствия нет — правые столбцы будут NULL.

2. Когда использовать CROSS JOIN на практике:
   - При генерации всех комбинаций (матрица расписания, тестовые комбинации, генерация сценариев).
   - Используйте с осторожностью — результат растёт мультипликативно.

3. Почему положение фильтра (ON vs WHERE) важно для OUTER JOIN:
   - Условие в ON влияет на то, какие строки будут сопоставлены (и поэтому какие будут NULL),
     но строки левой таблицы при LEFT JOIN всё равно остаются в результате.
   - WHERE применяется уже после соединения и может отфильтровать строки с NULL, тем самым отменив эффекты внешнего соединения.

4. Результат SELECT COUNT(*) FROM table1 CROSS JOIN table2 при 5 и 10 строках = 50.

5. NATURAL JOIN определяет колонки для соединения по одноимённым столбцам в обеих таблицах (по имени).

6. Риски NATURAL JOIN:
   - Невидимые соединения по новым одноимённым колонкам при изменении структуры базы — баги и неожиданные результаты.
   - Рекомендовано избегать в production; лучше явно указывать ON/USING.

7. Convert LEFT JOIN to RIGHT JOIN:
   - A LEFT JOIN B ON A.id = B.id  <=>  B RIGHT JOIN A ON A.id = B.id

8. Когда использовать FULL OUTER JOIN:
   - Когда нужно получить ВСЕ записи из обеих таблиц и выявить несоответствия с обеих сторон (orphan records).
*/


-- Additional Challenges (optional) — решения


-- 1) Симуляция FULL OUTER JOIN через UNION в СУБД без FULL JOIN:
SELECT e.emp_id, e.emp_name, d.dept_id, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
UNION
SELECT e.emp_id, e.emp_name, d.dept_id, d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id;

-- 2) Сотрудники, работающие в департаментах с более чем одним проектом
WITH proj_count AS (
    SELECT dept_id, COUNT(*) AS cnt
    FROM projects
    WHERE dept_id IS NOT NULL
    GROUP BY dept_id
    HAVING COUNT(*) > 1
)
SELECT e.emp_name, e.dept_id
FROM employees e
JOIN proj_count pc ON e.dept_id = pc.dept_id;
-- По данным: dept_id 101 имеет 2 проекта -> John и Mike в результате.

-- 3) Иерархический запрос (рекурсивный CTE) — показать структуру employee -> manager -> manager's manager
WITH RECURSIVE chain(emp_id, emp_name, manager_id, level, path) AS (
    SELECT emp_id, emp_name, manager_id, 1 AS level, emp_name::text AS path
    FROM employees
    WHERE manager_id IS NULL  -- стартуем с топ-менеджеров (если есть)
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.manager_id, c.level + 1, c.path || ' -> ' || e.emp_name
    FROM employees e
    JOIN chain c ON e.manager_id = c.emp_id
)
SELECT * FROM chain ORDER BY level, emp_id;

-- 4) Все пары сотрудников, работающих в одном департаменте
SELECT a.emp_name AS emp1, b.emp_name AS emp2, a.dept_id
FROM employees a
JOIN employees b ON a.dept_id = b.dept_id
WHERE a.emp_id < b.emp_id AND a.dept_id IS NOT NULL
ORDER BY a.dept_id, a.emp_name, b.emp_name;