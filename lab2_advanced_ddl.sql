-- Laboratory Work #2: Advanced DDL Operations
-- Part 1: Multiple Database Management

-- 1.1 Databases
CREATE DATABASE university_main
    OWNER = postgres
    TEMPLATE = template0
    ENCODING = 'UTF8';

CREATE DATABASE university_archive
    TEMPLATE = template0
    CONNECTION LIMIT = 50;

CREATE DATABASE university_test
    TEMPLATE = template0
    CONNECTION LIMIT = 10;

-- Пометка university_test как template (требует суперпользователя)
UPDATE pg_database
SET datistemplate = true
WHERE datname = 'university_test';

-- 1.2 Tablespaces
CREATE TABLESPACE student_data
    LOCATION 'C:/data/students';

CREATE TABLESPACE course_data
    OWNER = postgres
    LOCATION 'C:/data/courses';

CREATE DATABASE university_distributed
    TEMPLATE = template0
    TABLESPACE = student_data
    ENCODING = 'LATIN9'
    OWNER = postgres;

-- ============================
-- Part 2: Complex Table Creation
-- ============================

-- подключаемся к базе university_main
\connect university_main

-- Table: students
CREATE TABLE IF NOT EXISTS students (
    student_id      serial PRIMARY KEY,
    first_name      varchar(50),
    last_name       varchar(50),
    email           varchar(100),
    phone           char(15),
    date_of_birth   date,
    enrollment_date date,
    gpa             numeric(3,2),
    is_active       boolean,
    graduation_year smallint
);

-- Table: professors
CREATE TABLE IF NOT EXISTS professors (
    professor_id     serial PRIMARY KEY,
    first_name       varchar(50),
    last_name        varchar(50),
    email            varchar(100),
    office_number    varchar(20),
    hire_date        date,
    salary           numeric(12,2),
    is_tenured       boolean,
    years_experience integer
);

-- Table: courses
CREATE TABLE IF NOT EXISTS courses (
    course_id       serial PRIMARY KEY,
    course_code     char(8),
    course_title    varchar(100),
    description     text,
    credits         smallint,
    max_enrollment  integer,
    course_fee      numeric(10,2),
    is_online       boolean,
    created_at      timestamp without time zone DEFAULT now()
);

-- Table: class_schedule
CREATE TABLE IF NOT EXISTS class_schedule (
    schedule_id  serial PRIMARY KEY,
    course_id    integer,
    professor_id integer,
    classroom    varchar(20),
    class_date   date,
    start_time   time without time zone,
    end_time     time without time zone,
    duration     interval
);

-- Table: student_records
CREATE TABLE IF NOT EXISTS student_records (
    record_id             serial PRIMARY KEY,
    student_id            integer,
    course_id             integer,
    semester              varchar(20),
    year                  integer,
    grade                 char(2),
    attendance_percentage numeric(4,1),
    submission_timestamp  timestamp with time zone,
    last_updated          timestamp with time zone
);

-- ============================
-- Part 3: Advanced ALTER TABLE Operations
-- ============================

-- Modify students table
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS middle_name varchar(30);

ALTER TABLE students
    ADD COLUMN IF NOT EXISTS student_status varchar(20);

ALTER TABLE students
    ALTER COLUMN phone TYPE varchar(20);

ALTER TABLE students
    ALTER COLUMN student_status SET DEFAULT 'ACTIVE';

ALTER TABLE students
    ALTER COLUMN gpa SET DEFAULT 0.00;

-- Modify professors table
ALTER TABLE professors
    ADD COLUMN IF NOT EXISTS department_code char(5);

ALTER TABLE professors
    ADD COLUMN IF NOT EXISTS research_area text;

ALTER TABLE professors
    ALTER COLUMN years_experience TYPE smallint USING years_experience::smallint;

ALTER TABLE professors
    ALTER COLUMN is_tenured SET DEFAULT false;

ALTER TABLE professors
    ADD COLUMN IF NOT EXISTS last_promotion_date date;

-- Modify courses table
ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS prerequisite_course_id integer;

ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS difficulty_level smallint;

-- change course_code from char(8) to varchar(10)
ALTER TABLE courses
    ALTER COLUMN course_code TYPE varchar(10) USING trim(course_code)::varchar;

ALTER TABLE courses
    ALTER COLUMN credits SET DEFAULT 3;

ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS lab_required boolean DEFAULT false;

-- Part 3.2: Column Management for class_schedule and student_records

-- class_schedule changes
ALTER TABLE class_schedule
    ADD COLUMN IF NOT EXISTS room_capacity integer;

ALTER TABLE class_schedule
    DROP COLUMN IF EXISTS duration;

ALTER TABLE class_schedule
    ADD COLUMN IF NOT EXISTS session_type varchar(15);

ALTER TABLE class_schedule
    ALTER COLUMN classroom TYPE varchar(30);

ALTER TABLE class_schedule
    ADD COLUMN IF NOT EXISTS equipment_needed text;

-- student_records changes
ALTER TABLE student_records
    ADD COLUMN IF NOT EXISTS extra_credit_points numeric(4,1);

ALTER TABLE student_records
    ALTER COLUMN grade TYPE varchar(5) USING grade::varchar;

ALTER TABLE student_records
    ALTER COLUMN extra_credit_points SET DEFAULT 0.0;

ALTER TABLE student_records
    ADD COLUMN IF NOT EXISTS final_exam_date date;

ALTER TABLE student_records
    DROP COLUMN IF EXISTS last_updated;

-- ============================
-- Part 4: Table Relationships and Management
-- ============================

-- Additional supporting tables

CREATE TABLE IF NOT EXISTS departments (
    department_id     serial PRIMARY KEY,
    department_name   varchar(100),
    department_code   char(5),
    building          varchar(50),
    phone             varchar(15),
    budget            numeric(14,2),
    established_year  integer
);

CREATE TABLE IF NOT EXISTS library_books (
    book_id                 serial PRIMARY KEY,
    isbn                    char(13),
    title                   varchar(200),
    author                  varchar(100),
    publisher               varchar(100),
    publication_date        date,
    price                   numeric(10,2),
    is_available            boolean,
    acquisition_timestamp   timestamp without time zone
);

CREATE TABLE IF NOT EXISTS student_book_loans (
    loan_id     serial PRIMARY KEY,
    student_id  integer,
    book_id     integer,
    loan_date   date,
    due_date    date,
    return_date date,
    fine_amount numeric(10,2),
    loan_status varchar(20)
);

-- Add foreign-key columns (only columns, no constraints yet)
ALTER TABLE professors ADD COLUMN IF NOT EXISTS department_id integer;
ALTER TABLE students ADD COLUMN IF NOT EXISTS advisor_id integer;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS department_id integer;

-- Lookup tables
CREATE TABLE IF NOT EXISTS grade_scale (
    grade_id       serial PRIMARY KEY,
    letter_grade   char(2),
    min_percentage numeric(4,1),
    max_percentage numeric(4,1),
    gpa_points     numeric(3,2)
);

CREATE TABLE IF NOT EXISTS semester_calendar (
    semester_id              serial PRIMARY KEY,
    semester_name            varchar(20),
    academic_year            integer,
    start_date               date,
    end_date                 date,
    registration_deadline    timestamp with time zone,
    is_current               boolean
);

-- ============================
-- Part 5: Table Deletion and Cleanup
-- ============================

-- 5.1 Conditional table operations: drop if exists
DROP TABLE IF EXISTS student_book_loans;
DROP TABLE IF EXISTS library_books;
DROP TABLE IF EXISTS grade_scale;

-- Recreate grade_scale with additional column description (text)
CREATE TABLE grade_scale (
    grade_id       serial PRIMARY KEY,
    letter_grade   char(2),
    min_percentage numeric(4,1),
    max_percentage numeric(4,1),
    gpa_points     numeric(3,2),
    description    text
);

-- Drop and recreate semester_calendar with CASCADE
DROP TABLE IF EXISTS semester_calendar CASCADE;

CREATE TABLE semester_calendar (
    semester_id              serial PRIMARY KEY,
    semester_name            varchar(20),
    academic_year            integer,
    start_date               date,
    end_date                 date,
    registration_deadline    timestamp with time zone,
    is_current               boolean
);

-- 5.2 Database cleanup
-- переключимся на postgres для операций с базами
\connect postgres

-- Drop databases if they exist
DROP DATABASE IF EXISTS university_test;
DROP DATABASE IF EXISTS university_distributed;

-- Create new database university_backup using university_main as template
CREATE DATABASE university_backup TEMPLATE university_main;

-- ============================
-- End of script
-- ============================
