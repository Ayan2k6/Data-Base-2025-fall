-- ========== Part 1: CHECK Constraints ==========

-- Task 1.1: employees
CREATE TABLE employees (
    employee_id INTEGER,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK (age BETWEEN 18 AND 65), -- age must be between 18 and 65
    salary NUMERIC CHECK (salary > 0) -- salary must be > 0
);

-- Valid inserts (at least 2)
INSERT INTO employees VALUES (1, 'Alice', 'Ivanova', 25, 3000.00);
INSERT INTO employees VALUES (2, 'Bob', 'Sidorov', 45, 4500.50);

-- Invalid inserts (will fail) - commented out
-- INSERT INTO employees VALUES (3, 'TooYoung', 'User', 16, 2000); 
--  --> Violates CHECK (age BETWEEN 18 AND 65): age 16 < 18

-- INSERT INTO employees VALUES (4, 'NoSalary', 'User', 30, 0);
--  --> Violates CHECK (salary > 0): salary must be greater than 0

-- Task 1.2: products_catalog with named CHECK constraint valid_discount
CREATE TABLE products_catalog (
    product_id INTEGER,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 
        AND discount_price > 0 
        AND discount_price < regular_price
    )
);

-- Valid inserts
INSERT INTO products_catalog VALUES (1, 'Gadget A', 100.00, 80.00);
INSERT INTO products_catalog VALUES (2, 'Gadget B', 250.00, 200.00);

-- Invalid inserts (commented)
-- INSERT INTO products_catalog VALUES (3, 'BadPrice', 0, 0);
-- --> Violates valid_discount: regular_price must be > 0

-- INSERT INTO products_catalog VALUES (4, 'BadDiscount', 100, 150);
-- --> Violates valid_discount: discount_price < regular_price

-- Task 1.3: bookings with multi-column check
CREATE TABLE bookings (
    booking_id INTEGER,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INTEGER CHECK (num_guests BETWEEN 1 AND 10), -- guests 1..10
    CHECK (check_out_date > check_in_date) -- check_out must be after check_in
);

-- Valid inserts
INSERT INTO bookings VALUES (1, '2025-10-01', '2025-10-05', 2);
INSERT INTO bookings VALUES (2, '2025-11-10', '2025-11-12', 4);

-- Invalid inserts
-- INSERT INTO bookings VALUES (3, '2025-09-10', '2025-09-09', 2);
-- --> Violates CHECK (check_out_date > check_in_date): out before in

-- INSERT INTO bookings VALUES (4, '2025-12-01', '2025-12-03', 0);
-- --> Violates num_guests CHECK: num_guests must be between 1 and 10

-- ========== Part 2: NOT NULL Constraints ==========

-- Task 2.1: customers
CREATE TABLE customers (
    customer_id INTEGER NOT NULL,
    email TEXT NOT NULL,
    phone TEXT, -- nullable
    registration_date DATE NOT NULL
);

-- Valid inserts
INSERT INTO customers VALUES (1, 'alice@example.com', '87001234567', '2025-01-10');
INSERT INTO customers VALUES (2, 'bob@example.com', NULL, '2025-02-20');

-- Invalid inserts (commented)
-- INSERT INTO customers VALUES (3, NULL, '87009998877', '2025-03-01');
-- --> Violates NOT NULL on email

-- INSERT INTO customers VALUES (NULL, 'c@example.com', NULL, '2025-03-02');
-- --> Violates NOT NULL on customer_id

-- Task 2.2: inventory with NOT NULL + checks
CREATE TABLE inventory (
    item_id INTEGER NOT NULL,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0), -- quantity >= 0
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0), -- price > 0
    last_updated TIMESTAMP NOT NULL
);

-- Valid inserts
INSERT INTO inventory VALUES (1, 'Screwdriver', 50, 5.50, '2025-04-01 10:00:00');
INSERT INTO inventory VALUES (2, 'Hammer', 20, 12.00, '2025-04-02 09:00:00');

-- Invalid inserts
-- INSERT INTO inventory VALUES (3, 'FreeItem', -5, 1.00, '2025-04-03 08:00:00');
-- --> Violates CHECK (quantity >= 0)

-- INSERT INTO inventory VALUES (4, 'ZeroPrice', 10, 0, '2025-04-04 08:00:00');
-- --> Violates CHECK (unit_price > 0)

-- Task 2.3: testing NULL in nullable column (phone is nullable)
INSERT INTO customers VALUES (3, 'charlie@example.com', NULL, '2025-05-05'); -- allowed

-- ========== Part 3: UNIQUE Constraints ==========

-- Task 3.1 & 3.3: users with named unique constraints
CREATE TABLE users (
    user_id INTEGER,
    username TEXT,
    email TEXT,
    created_at TIMESTAMP,
    CONSTRAINT unique_username UNIQUE (username),
    CONSTRAINT unique_email UNIQUE (email)
);

-- Valid inserts
INSERT INTO users VALUES (1, 'alice123', 'aliceu@example.com', '2025-06-01 10:00:00');
INSERT INTO users VALUES (2, 'bob123', 'bobu@example.com', '2025-06-02 11:00:00');

-- Invalid inserts (duplicates)
-- INSERT INTO users VALUES (3, 'alice123', 'alice2@example.com', now());
-- --> Violates unique_username (username 'alice123' already exists)

-- INSERT INTO users VALUES (4, 'charlie', 'bobu@example.com', now());
-- --> Violates unique_email (email 'bobu@example.com' already exists)

-- Task 3.2: course_enrollments with multi-column UNIQUE
CREATE TABLE course_enrollments (
    enrollment_id INTEGER,
    student_id INTEGER,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT unique_enrollment UNIQUE (student_id, course_code, semester)
);

-- Valid inserts
INSERT INTO course_enrollments VALUES (1, 1001, 'CS101', 'Fall2025');
INSERT INTO course_enrollments VALUES (2, 1002, 'CS101', 'Fall2025');

-- Invalid insert (duplicate same student, course, semester)
-- INSERT INTO course_enrollments VALUES (3, 1001, 'CS101', 'Fall2025');
-- --> Violates unique_enrollment: same student_id + course_code + semester

-- ========== Part 4: PRIMARY KEY Constraints ==========

-- Task 4.1: departments with single-column PK
CREATE TABLE departments (
    dept_id INTEGER PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

-- Valid inserts (3)
INSERT INTO departments VALUES (10, 'Computer Science', 'Building A');
INSERT INTO departments VALUES (20, 'Mathematics', 'Building B');
INSERT INTO departments VALUES (30, 'Physics', 'Building C');

-- Invalid attempts
-- INSERT INTO departments VALUES (10, 'Duplicate Dept', 'Somewhere');
-- --> Violates PRIMARY KEY unique constraint on dept_id (10 already used)

-- INSERT INTO departments VALUES (NULL, 'No ID', 'Nowhere');
-- --> Violates PRIMARY KEY NOT NULL on dept_id

-- Task 4.2: student_courses with composite primary key
CREATE TABLE student_courses (
    student_id INTEGER,
    course_id INTEGER,
    enrollment_date DATE,
    grade TEXT,
    PRIMARY KEY (student_id, course_id) -- composite PK
);

-- Valid inserts
INSERT INTO student_courses VALUES (1001, 501, '2025-09-01', 'A');
INSERT INTO student_courses VALUES (1002, 501, '2025-09-02', 'B');

-- Invalid insert (duplicate composite PK)
-- INSERT INTO student_courses VALUES (1001, 501, '2025-09-03', 'C');
-- --> Violates PRIMARY KEY (student_id, course_id) combination already exists

-- Task 4.3: Comparison (as comments)
-- UNIQUE vs PRIMARY KEY:
--  - PRIMARY KEY uniquely identifies rows and implies NOT NULL.
--  - UNIQUE enforces uniqueness but allows NULLs (unless declared NOT NULL).
-- Single-column vs composite PRIMARY KEY:
--  - Use single-column PK when one column uniquely identifies a row (e.g., id).
--  - Use composite PK when uniqueness comes from combination of columns (e.g., student + course).
-- One PRIMARY KEY per table:
--  - A table can only have one PRIMARY KEY (but that PK can consist of multiple columns).
--  - A table can have many UNIQUE constraints.

-- ========== Part 5: FOREIGN KEY Constraints ==========

-- Task 5.1: employees_dept referencing departments
CREATE TABLE employees_dept (
    emp_id INTEGER PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id), -- FK to departments.dept_id
    hire_date DATE
);

-- Valid insert (dept exists)
INSERT INTO employees_dept VALUES (101, 'Dina', 10, '2025-07-01');

-- Invalid insert (non-existent dept_id)
-- INSERT INTO employees_dept VALUES (102, 'Egor', 99, '2025-07-02');
-- --> Violates FOREIGN KEY: dept_id 99 does not exist in departments

-- Task 5.2: Library schema (authors, publishers, books)
CREATE TABLE authors (
    author_id INTEGER PRIMARY KEY,
    author_name TEXT NOT NULL,
    country TEXT
);

CREATE TABLE publishers (
    publisher_id INTEGER PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city TEXT
);

CREATE TABLE books (
    book_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(author_id),
    publisher_id INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn TEXT UNIQUE
);

-- Sample inserts
INSERT INTO authors VALUES (1, 'Leo Tolstoy', 'Russia');
INSERT INTO authors VALUES (2, 'Jane Austen', 'UK');

INSERT INTO publishers VALUES (1, 'Penguin Books', 'London');
INSERT INTO publishers VALUES (2, 'Mir Publishers', 'Moscow');

INSERT INTO books VALUES (1, 'War and Peace', 1, 2, 1869, 'ISBN-0001');
INSERT INTO books VALUES (2, 'Pride and Prejudice', 2, 1, 1813, 'ISBN-0002');

-- Task 5.3: ON DELETE behaviors

CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT
    -- RESTRICT: can't delete category if products reference it
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    item_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity INTEGER CHECK (quantity > 0)
);

-- Insert sample categories and products
INSERT INTO categories VALUES (1, 'Electronics');
INSERT INTO categories VALUES (2, 'Books');

INSERT INTO products_fk VALUES (100, 'Smartphone', 1);
INSERT INTO products_fk VALUES (101, 'Novel', 2);

-- Insert order and order_items
INSERT INTO orders VALUES (5000, '2025-09-20');
INSERT INTO order_items VALUES (1, 5000, 100, 2);

-- Tests (commented and explained)
-- 1) Try to delete a category that has products (should fail with RESTRICT)
-- DELETE FROM categories WHERE category_id = 1;
-- --> Fails: products_fk references category_id 1 and ON DELETE RESTRICT prevents deletion.

-- 2) Delete an order and observe order_items automatically deleted (CASCADE)
-- DELETE FROM orders WHERE order_id = 5000;
-- --> This will delete the order and automatically delete order_items where order_id=5000.

-- ========== Part 6: Practical Application (E-commerce) ==========

-- Task 6.1: E-commerce schema

CREATE TABLE ec_customers (
    customer_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE, -- unique email
    phone TEXT,
    registration_date DATE NOT NULL
);

CREATE TABLE ec_products (
    product_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC CHECK (price >= 0), -- non-negative price
    stock_quantity INTEGER CHECK (stock_quantity >= 0) -- non-negative stock
);

CREATE TABLE ec_orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES ec_customers(customer_id) ON DELETE SET NULL,
    order_date DATE NOT NULL,
    total_amount NUMERIC CHECK (total_amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
    -- order status restricted to allowed values
);

CREATE TABLE ec_order_details (
    order_detail_id INTEGER PRIMARY KEY,
    order_id INTEGER REFERENCES ec_orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES ec_products(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0), -- quantity must be positive
    unit_price NUMERIC NOT NULL CHECK (unit_price >= 0)
);

-- Insert at least 5 sample records per table

-- ec_customers (5)
INSERT INTO ec_customers VALUES (1, 'Alice Example', 'alice.ex@example.com', '87001112233', '2025-01-01');
INSERT INTO ec_customers VALUES (2, 'Bob Example', 'bob.ex@example.com', '87002223344', '2025-02-02');
INSERT INTO ec_customers VALUES (3, 'Charlie Example', 'charlie.ex@example.com', NULL, '2025-03-03');
INSERT INTO ec_customers VALUES (4, 'Diana Example', 'diana.ex@example.com', '87003334455', '2025-04-04');
INSERT INTO ec_customers VALUES (5, 'Egor Example', 'egor.ex@example.com', '87004445566', '2025-05-05');

-- ec_products (5)
INSERT INTO ec_products VALUES (1001, 'Laptop', 'Light laptop', 1200.00, 10);
INSERT INTO ec_products VALUES (1002, 'Mouse', 'Wireless mouse', 25.00, 100);
INSERT INTO ec_products VALUES (1003, 'Keyboard', 'Mechanical', 75.00, 50);
INSERT INTO ec_products VALUES (1004, 'Monitor', '24 inch', 200.00, 20);
INSERT INTO ec_products VALUES (1005, 'USB Cable', '1m cable', 5.00, 500);

-- ec_orders (5) — ensure customer ids exist
INSERT INTO ec_orders VALUES (9001, 1, '2025-09-01', 1250.00, 'pending');
INSERT INTO ec_orders VALUES (9002, 2, '2025-09-02', 25.00, 'processing');
INSERT INTO ec_orders VALUES (9003, 1, '2025-09-03', 205.00, 'shipped');
INSERT INTO ec_orders VALUES (9004, 3, '2025-09-04', 5.00, 'delivered');
INSERT INTO ec_orders VALUES (9005, 4, '2025-09-05', 300.00, 'cancelled');

-- ec_order_details (5) — match order totals roughly
INSERT INTO ec_order_details VALUES (1, 9001, 1001, 1, 1200.00); -- Laptop
INSERT INTO ec_order_details VALUES (2, 9001, 1002, 2, 25.00);   -- 2x Mouse => total 1250
INSERT INTO ec_order_details VALUES (3, 9002, 1002, 1, 25.00);
INSERT INTO ec_order_details VALUES (4, 9003, 1004, 1, 200.00);
INSERT INTO ec_order_details VALUES (5, 9004, 1005, 1, 5.00);

-- Test queries demonstrating constraints

-- 1) UNIQUE on email: attempting duplicate email (commented)
-- INSERT INTO ec_customers VALUES (6, 'New', 'alice.ex@example.com', NULL, '2025-09-06');
-- --> Violates UNIQUE constraint on email.

-- 2) Price non-negative: invalid product (commented)
-- INSERT INTO ec_products VALUES (2000, 'Broken', 'Negative price', -10, 5);
-- --> Violates CHECK (price >= 0).

-- 3) Order status validation: invalid status (commented)
-- INSERT INTO ec_orders VALUES (9010, 1, '2025-09-10', 10.00, 'waiting');
-- --> Violates CHECK on status: 'waiting' not allowed.

-- 4) Quantity positive in order_details (commented)
-- INSERT INTO ec_order_details VALUES (6, 9001, 1002, 0, 25.00);
-- --> Violates CHECK (quantity > 0).

-- 5) ON DELETE CASCADE for ec_orders -> ec_order_details:
-- DELETE FROM ec_orders WHERE order_id = 9002;
-- --> This will delete order 9002 and its ec_order_details with order_id=9002 automatically.

-- 6) ON DELETE RESTRICT for ec_products referenced by ec_order_details:
-- DELETE FROM ec_products WHERE product_id = 1001;
-- --> Will fail if there are ec_order_details referencing product_id=1001 (RESTRICT).

-- Additional test selects (to view data)
SELECT * FROM employees;
SELECT * FROM products_catalog;
SELECT * FROM bookings;
SELECT * FROM customers;
SELECT * FROM inventory;
SELECT * FROM users;
SELECT * FROM course_enrollments;
SELECT * FROM departments;
SELECT * FROM student_courses;
SELECT * FROM employees_dept;
SELECT * FROM authors;
SELECT * FROM publishers;
SELECT * FROM books;
SELECT * FROM categories;
SELECT * FROM products_fk;
SELECT * FROM orders;
SELECT * FROM order_items;
SELECT * FROM ec_customers;
SELECT * FROM ec_products;
SELECT * FROM ec_orders;
SELECT * FROM ec_order_details;