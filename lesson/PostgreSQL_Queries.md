# PostgreSQL Queries in Detail

**Category:** PostgreSQL -- SQL Querying & Data Manipulation
**Subcategory:** SELECT, JOINs, Aggregation, Window Functions, Subqueries, DML, Query Planning
**Prerequisites:** Basic SQL syntax (CREATE TABLE, simple SELECT), PostgreSQL installed or accessible, familiarity with relational concepts (tables, rows, columns, primary/foreign keys)

---

## The Big Picture

Every time your MarkedQuiz app loads a document, runs a quiz, or records a score, a SQL query executes against PostgreSQL. But what actually happens between "your code sends a query" and "data comes back"? Understanding this pipeline changes how you write queries.

```
+====================================================================+
|                   HOW POSTGRESQL PROCESSES A QUERY                   |
+====================================================================+
|                                                                     |
|  Your App (FastAPI / SQLAlchemy / psql)                             |
|       |                                                             |
|       | 1. SQL string sent over connection                          |
|       v                                                             |
|  +--------------------------------------------------------------+  |
|  |  PARSER                                                      |  |
|  |  - Checks syntax (is this valid SQL?)                        |  |
|  |  - Builds a parse tree (abstract representation)             |  |
|  |  - Catches typos: "SELCT" --> syntax error here              |  |
|  +--------------------------------------------------------------+  |
|       |                                                             |
|       v                                                             |
|  +--------------------------------------------------------------+  |
|  |  ANALYZER / REWRITER                                         |  |
|  |  - Resolves table/column names (does "users" exist?)         |  |
|  |  - Checks permissions (can this role SELECT from users?)     |  |
|  |  - Expands views, applies rules                              |  |
|  +--------------------------------------------------------------+  |
|       |                                                             |
|       v                                                             |
|  +--------------------------------------------------------------+  |
|  |  PLANNER / OPTIMIZER                                         |  |
|  |  - Considers multiple strategies to get the data             |  |
|  |  - Estimates cost of each strategy using table statistics     |  |
|  |  - Picks the cheapest plan                                    |  |
|  |  - This is where index vs. sequential scan is decided        |  |
|  +--------------------------------------------------------------+  |
|       |                                                             |
|       v                                                             |
|  +--------------------------------------------------------------+  |
|  |  EXECUTOR                                                    |  |
|  |  - Actually reads data from disk / shared buffers            |  |
|  |  - Applies filters, sorts, joins, aggregations               |  |
|  |  - Streams results back to the client                        |  |
|  +--------------------------------------------------------------+  |
|       |                                                             |
|       v                                                             |
|  Result rows returned to your app                                   |
|                                                                     |
+====================================================================+
```

The key insight: **the planner is the brain**. Two queries that return identical results can perform wildly differently because the planner chose different strategies. Learning to write queries that help the planner make good choices is what separates fast apps from slow ones.

**Question to think about:** When you write `session.query(Document).filter(Document.id == 5)` in SQLAlchemy, which of these stages does SQLAlchemy participate in? Which stages happen entirely inside PostgreSQL?

---

## Our Running Example: The MarkedQuiz Schema

Every example in this lesson uses these tables. Refer back here when a query references a table.

```sql
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(50) UNIQUE NOT NULL,
    email       VARCHAR(255) UNIQUE NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE documents (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tags (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE document_tags (
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    tag_id      INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (document_id, tag_id)
);

CREATE TABLE quizzes (
    id          SERIAL PRIMARY KEY,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    title       VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE quiz_attempts (
    id           SERIAL PRIMARY KEY,
    quiz_id      INTEGER REFERENCES quizzes(id) ON DELETE CASCADE,
    user_id      INTEGER REFERENCES users(id) ON DELETE CASCADE,
    score        INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
    completed_at TIMESTAMPTZ DEFAULT now()
);
```

```
+==============================================================+
|                    SCHEMA RELATIONSHIP MAP                     |
+==============================================================+
|                                                               |
|  users ---< quiz_attempts >--- quizzes ---< documents        |
|                                                               |
|                                  documents >--< tags          |
|                                     (via document_tags)       |
|                                                               |
|  Legend:  ---<  means "one to many"                           |
|           >--<  means "many to many"                         |
|                                                               |
+==============================================================+
```

---

## Chapter 1: SELECT Fundamentals

### Column Selection and Aliases

The simplest query selects columns from a table:

```sql
SELECT id, title, created_at
FROM documents;
```

Aliases rename columns in the output. Use them to make results readable or to disambiguate columns from different tables:

```sql
SELECT
    id AS document_id,
    title AS document_title,
    created_at AS published
FROM documents;
```

In SQLAlchemy, this is `select(Document.id.label('document_id'), Document.title.label('document_title'))`.

### Expressions in SELECT

You are not limited to raw columns. The SELECT list can contain expressions:

```sql
SELECT
    id,
    title,
    LENGTH(content) AS content_length,
    created_at::DATE AS created_date,
    now() - created_at AS age
FROM documents;
```

Each row gets these expressions evaluated independently. `LENGTH(content)` computes the character count of that row's content. `created_at::DATE` casts the timestamp to just the date portion. `now() - created_at` gives you an `INTERVAL` representing how old the document is.

### DISTINCT

`DISTINCT` removes duplicate rows from the result:

```sql
-- All unique scores anyone has achieved
SELECT DISTINCT score
FROM quiz_attempts
ORDER BY score;
```

`DISTINCT ON` is a PostgreSQL extension that keeps only the first row for each distinct value of the specified columns:

```sql
-- Most recent attempt per user per quiz
SELECT DISTINCT ON (user_id, quiz_id)
    user_id, quiz_id, score, completed_at
FROM quiz_attempts
ORDER BY user_id, quiz_id, completed_at DESC;
```

**This is powerful.** `DISTINCT ON` requires that the `ORDER BY` starts with the same columns listed in `DISTINCT ON`. The ordering after those columns determines which row "wins" -- here, `completed_at DESC` means the most recent attempt survives.

### CASE Expressions

`CASE` is SQL's if/else. It evaluates conditions and returns a value:

```sql
SELECT
    username,
    score,
    CASE
        WHEN score >= 90 THEN 'Excellent'
        WHEN score >= 70 THEN 'Good'
        WHEN score >= 50 THEN 'Needs Work'
        ELSE 'Failed'
    END AS grade
FROM quiz_attempts
JOIN users ON users.id = quiz_attempts.user_id;
```

`CASE` works anywhere an expression is valid -- in `SELECT`, `WHERE`, `ORDER BY`, even inside aggregate functions. You will use it constantly.

**Question to think about:** How would you write a query that counts how many attempts fall into each grade category (Excellent, Good, Needs Work, Failed) without using a subquery?

---

## Chapter 2: Filtering with WHERE

### Comparison Operators

```sql
-- Exact match
SELECT * FROM documents WHERE id = 5;

-- Not equal (both forms work, <> is SQL standard)
SELECT * FROM users WHERE username <> 'admin';
SELECT * FROM users WHERE username != 'admin';

-- Range comparisons
SELECT * FROM quiz_attempts WHERE score >= 80;
SELECT * FROM documents WHERE created_at > '2025-01-01';
```

### Combining Conditions: AND, OR, NOT

```sql
-- Both conditions must be true
SELECT * FROM quiz_attempts
WHERE score >= 80 AND completed_at > '2025-06-01';

-- Either condition can be true
SELECT * FROM documents
WHERE title LIKE '%PostgreSQL%' OR title LIKE '%SQL%';

-- Negation
SELECT * FROM users
WHERE NOT username = 'admin';
```

**Precedence matters.** `AND` binds tighter than `OR`. This is a common bug source:

```sql
-- WRONG: finds (score > 90) OR (any row with quiz_id = 3)
SELECT * FROM quiz_attempts
WHERE score > 90 OR score < 20 AND quiz_id = 3;

-- RIGHT: use parentheses to clarify intent
SELECT * FROM quiz_attempts
WHERE (score > 90 OR score < 20) AND quiz_id = 3;
```

Always use parentheses when mixing AND and OR. Future you will thank present you.

### IN, BETWEEN, IS NULL

```sql
-- IN: matches any value in the list
SELECT * FROM documents WHERE id IN (1, 3, 5, 7);

-- BETWEEN: inclusive range (equivalent to >= AND <=)
SELECT * FROM quiz_attempts WHERE score BETWEEN 70 AND 90;

-- IS NULL / IS NOT NULL (never use = NULL, it doesn't work)
SELECT * FROM documents WHERE updated_at IS NULL;
```

**Why does `= NULL` not work?** In SQL, NULL means "unknown." Comparing anything to unknown yields unknown (not true, not false). `WHERE score = NULL` is never true for any row, even rows where score is actually NULL. This trips up every beginner at least once.

In SQLAlchemy: `Document.updated_at.is_(None)` -- not `Document.updated_at == None` (though SQLAlchemy does translate `== None` to `IS NULL`, the explicit form is clearer).

### Pattern Matching: LIKE and ILIKE

```sql
-- LIKE: case-sensitive pattern matching
-- % = any sequence of characters, _ = exactly one character
SELECT * FROM documents WHERE title LIKE 'PostgreSQL%';
SELECT * FROM documents WHERE title LIKE '___';  -- exactly 3 characters

-- ILIKE: case-insensitive (PostgreSQL extension)
SELECT * FROM documents WHERE title ILIKE '%postgresql%';
```

For more complex patterns, PostgreSQL supports POSIX regular expressions:

```sql
-- ~ for case-sensitive regex, ~* for case-insensitive
SELECT * FROM documents WHERE title ~* '^(post|pg).*sql';
```

**Question to think about:** If you have 10 million documents and you search with `WHERE title ILIKE '%query%'`, what kind of scan will PostgreSQL use? Can a regular B-tree index help here? (Hint: think about what the `%` at the beginning means for index lookups.)

---

## Chapter 3: Sorting and Limiting

### ORDER BY

```sql
-- Simple sort
SELECT * FROM documents ORDER BY created_at DESC;

-- Multiple columns: sort by first, break ties with second
SELECT * FROM quiz_attempts
ORDER BY quiz_id ASC, score DESC;

-- Sort by expression
SELECT * FROM documents
ORDER BY LENGTH(title);

-- Sort by column position (fragile, avoid in production code)
SELECT id, title, created_at FROM documents ORDER BY 3 DESC;

-- NULLS FIRST / NULLS LAST
SELECT * FROM documents ORDER BY updated_at DESC NULLS LAST;
```

By default, `ASC` puts NULLs last and `DESC` puts NULLs first. The `NULLS FIRST` / `NULLS LAST` clause overrides this.

### LIMIT and OFFSET

```sql
-- First 10 documents
SELECT * FROM documents ORDER BY created_at DESC LIMIT 10;

-- Skip first 20, return next 10 (page 3 of 10-per-page)
SELECT * FROM documents ORDER BY created_at DESC LIMIT 10 OFFSET 20;
```

The SQL standard equivalent (which PostgreSQL also supports):

```sql
SELECT * FROM documents
ORDER BY created_at DESC
FETCH FIRST 10 ROWS ONLY;
```

### The OFFSET Pagination Problem

```
+================================================================+
|                OFFSET PAGINATION: THE HIDDEN COST               |
+================================================================+
|                                                                 |
|  Page 1: LIMIT 10 OFFSET 0   --> PostgreSQL reads 10 rows      |
|  Page 2: LIMIT 10 OFFSET 10  --> PostgreSQL reads 20 rows,     |
|                                   discards first 10             |
|  Page 3: LIMIT 10 OFFSET 20  --> PostgreSQL reads 30 rows,     |
|                                   discards first 20             |
|  ...                                                            |
|  Page 1000: LIMIT 10 OFFSET 9990                                |
|           --> PostgreSQL reads 10,000 rows, discards 9,990      |
|                                                                 |
|  OFFSET forces PostgreSQL to scan and throw away rows.          |
|  Deep pages get progressively slower.                           |
|                                                                 |
|  ALTERNATIVE: Keyset (cursor) pagination                        |
|  ------------------------------------------------               |
|  Instead of OFFSET, use the last seen value:                    |
|                                                                 |
|  Page 1: WHERE created_at < now()                               |
|           ORDER BY created_at DESC LIMIT 10                     |
|                                                                 |
|  Page 2: WHERE created_at < '2025-03-15T10:30:00Z'             |
|           ORDER BY created_at DESC LIMIT 10                     |
|           (where the timestamp is the last row from page 1)     |
|                                                                 |
|  This is O(1) per page regardless of depth.                     |
|                                                                 |
+================================================================+
```

Keyset pagination is what you should use in your FastAPI endpoints when the dataset could grow. OFFSET pagination is fine for admin dashboards or datasets you know will stay small.

In SQLAlchemy:

```python
# OFFSET pagination (simple, slow for deep pages)
stmt = select(Document).order_by(Document.created_at.desc()).offset(20).limit(10)

# Keyset pagination (fast at any depth)
stmt = (
    select(Document)
    .where(Document.created_at < last_seen_timestamp)
    .order_by(Document.created_at.desc())
    .limit(10)
)
```

---

## Chapter 4: Aggregation

### Aggregate Functions

Aggregate functions collapse multiple rows into a single value:

```sql
SELECT
    COUNT(*) AS total_attempts,
    COUNT(DISTINCT user_id) AS unique_users,
    AVG(score) AS average_score,
    MIN(score) AS lowest_score,
    MAX(score) AS highest_score,
    SUM(score) AS total_points
FROM quiz_attempts;
```

`COUNT(*)` counts all rows. `COUNT(column)` counts non-NULL values. `COUNT(DISTINCT column)` counts unique non-NULL values. These three behave differently -- know which one you need.

### GROUP BY

`GROUP BY` partitions rows into groups before applying aggregates:

```sql
-- Average score per quiz
SELECT
    quiz_id,
    COUNT(*) AS attempt_count,
    ROUND(AVG(score), 1) AS avg_score
FROM quiz_attempts
GROUP BY quiz_id;
```

**The rule:** Every column in your `SELECT` must either appear in `GROUP BY` or be inside an aggregate function. This is not an arbitrary restriction -- it's logically necessary. If you group by `quiz_id`, each group has multiple `user_id` values. Which one should PostgreSQL show? It doesn't know, so it refuses.

```sql
-- ERROR: user_id must appear in GROUP BY or an aggregate
SELECT quiz_id, user_id, AVG(score)
FROM quiz_attempts
GROUP BY quiz_id;
```

### HAVING: Filtering Groups

`WHERE` filters individual rows before grouping. `HAVING` filters groups after aggregation:

```sql
-- Quizzes with more than 5 attempts and average score below 70
SELECT
    quiz_id,
    COUNT(*) AS attempt_count,
    ROUND(AVG(score), 1) AS avg_score
FROM quiz_attempts
GROUP BY quiz_id
HAVING COUNT(*) > 5 AND AVG(score) < 70;
```

```
+================================================================+
|              WHERE vs. HAVING EXECUTION ORDER                    |
+================================================================+
|                                                                  |
|  FROM quiz_attempts                                              |
|       |                                                          |
|       v                                                          |
|  WHERE score > 0          <-- filters individual rows FIRST      |
|       |                                                          |
|       v                                                          |
|  GROUP BY quiz_id         <-- groups the surviving rows          |
|       |                                                          |
|       v                                                          |
|  HAVING COUNT(*) > 5      <-- filters groups AFTER aggregation   |
|       |                                                          |
|       v                                                          |
|  SELECT quiz_id, AVG(...) <-- compute final output               |
|       |                                                          |
|       v                                                          |
|  ORDER BY avg_score       <-- sort the results                   |
|                                                                  |
+================================================================+
```

**Question to think about:** If you want to find the average score per quiz, but only counting attempts where the score is above 0 (ignoring zeros), should you put `score > 0` in the WHERE or the HAVING clause? Why?

---

## Chapter 5: JOINs in Depth

JOINs combine rows from two or more tables based on a related column. This is the heart of relational databases.

### INNER JOIN

Returns only rows that have matches in both tables:

```sql
SELECT
    q.title AS quiz_title,
    d.title AS document_title
FROM quizzes q
INNER JOIN documents d ON d.id = q.document_id;
```

```
+================================================================+
|                        INNER JOIN                                |
+================================================================+
|                                                                  |
|  documents                    quizzes                            |
|  +-----+--------+           +-----+---------+-----+             |
|  | id  | title  |           | id  | title   | d_id|             |
|  +-----+--------+           +-----+---------+-----+             |
|  |  1  | Doc A  |           |  1  | Quiz X  |  1  |             |
|  |  2  | Doc B  |           |  2  | Quiz Y  |  1  |             |
|  |  3  | Doc C  |           |  3  | Quiz Z  |  3  |             |
|  +-----+--------+           +-----+---------+-----+             |
|                                                                  |
|  Result (only matching rows from BOTH sides):                    |
|  +--------+--------+---------+                                   |
|  | doc_id | doc    | quiz    |                                   |
|  +--------+--------+---------+                                   |
|  |   1    | Doc A  | Quiz X  |  <-- Doc A matched                |
|  |   1    | Doc A  | Quiz Y  |  <-- Doc A matched again          |
|  |   3    | Doc C  | Quiz Z  |  <-- Doc C matched                |
|  +--------+--------+---------+                                   |
|                                                                  |
|  Doc B (id=2) has NO quizzes --> excluded from results           |
|                                                                  |
+================================================================+
```

### LEFT JOIN (LEFT OUTER JOIN)

Returns all rows from the left table, plus matching rows from the right. Where there is no match, right-side columns are NULL:

```sql
SELECT
    d.title AS document_title,
    q.title AS quiz_title
FROM documents d
LEFT JOIN quizzes q ON q.document_id = d.id;
```

```
+================================================================+
|                        LEFT JOIN                                 |
+================================================================+
|                                                                  |
|  documents (LEFT)             quizzes (RIGHT)                    |
|  +-----+--------+           +-----+---------+-----+             |
|  | id  | title  |           | id  | title   | d_id|             |
|  +-----+--------+           +-----+---------+-----+             |
|  |  1  | Doc A  |           |  1  | Quiz X  |  1  |             |
|  |  2  | Doc B  |           |  2  | Quiz Y  |  1  |             |
|  |  3  | Doc C  |           |  3  | Quiz Z  |  3  |             |
|  +-----+--------+           +-----+---------+-----+             |
|                                                                  |
|  Result (ALL left rows, NULLs where no match on right):         |
|  +--------+--------+---------+                                   |
|  | doc_id | doc    | quiz    |                                   |
|  +--------+--------+---------+                                   |
|  |   1    | Doc A  | Quiz X  |                                   |
|  |   1    | Doc A  | Quiz Y  |                                   |
|  |   2    | Doc B  | NULL    |  <-- Doc B kept, no quiz match    |
|  |   3    | Doc C  | Quiz Z  |                                   |
|  +--------+--------+---------+                                   |
|                                                                  |
+================================================================+
```

This is the most common JOIN in application code. Use it when you want all records from the primary table regardless of whether related data exists.

In SQLAlchemy: `select(Document, Quiz).outerjoin(Quiz, Quiz.document_id == Document.id)`.

### RIGHT JOIN (RIGHT OUTER JOIN)

The mirror of LEFT JOIN -- all rows from the right table, NULLs from the left where no match. In practice, you almost never need RIGHT JOIN because you can always rewrite it as a LEFT JOIN by swapping the table order.

### FULL OUTER JOIN

Returns all rows from both tables. Where there is no match, NULLs fill in the missing side:

```
+================================================================+
|                      FULL OUTER JOIN                             |
+================================================================+
|                                                                  |
|  Result (ALL rows from BOTH sides):                              |
|  +--------+--------+---------+                                   |
|  | doc_id | doc    | quiz    |                                   |
|  +--------+--------+---------+                                   |
|  |   1    | Doc A  | Quiz X  |                                   |
|  |   1    | Doc A  | Quiz Y  |                                   |
|  |   2    | Doc B  | NULL    |  <-- no quiz for this doc         |
|  |   3    | Doc C  | Quiz Z  |                                   |
|  |  NULL  | NULL   | Quiz W  |  <-- orphan quiz (if it existed)  |
|  +--------+--------+---------+                                   |
|                                                                  |
|  Useful for finding unmatched rows on EITHER side.               |
|                                                                  |
+================================================================+
```

### CROSS JOIN

Produces the Cartesian product -- every row from the left combined with every row from the right. If table A has 3 rows and table B has 4 rows, you get 12 result rows. Rarely used intentionally but important to understand because a missing JOIN condition produces one accidentally:

```sql
-- Intentional: generate all possible user-quiz combinations
SELECT u.username, q.title
FROM users u
CROSS JOIN quizzes q;
```

### Self-Joins

A table joined to itself. Useful for comparing rows within the same table:

```sql
-- Find users who share the same email domain
SELECT
    u1.username AS user_a,
    u2.username AS user_b,
    SPLIT_PART(u1.email, '@', 2) AS domain
FROM users u1
JOIN users u2
    ON SPLIT_PART(u1.email, '@', 2) = SPLIT_PART(u2.email, '@', 2)
    AND u1.id < u2.id;  -- avoid pairing a user with themselves and avoid duplicates
```

### JOIN Conditions vs. WHERE

This matters more than people realize. For INNER JOINs, putting a condition in `ON` vs. `WHERE` gives the same result. For OUTER JOINs, it changes the output:

```sql
-- LEFT JOIN with filter in ON: keeps all documents,
-- but only joins quizzes created in 2025
SELECT d.title, q.title
FROM documents d
LEFT JOIN quizzes q
    ON q.document_id = d.id
    AND q.created_at >= '2025-01-01';
-- Documents without 2025 quizzes still appear (with NULL quiz)

-- LEFT JOIN with filter in WHERE: filters AFTER the join,
-- removing documents that didn't match
SELECT d.title, q.title
FROM documents d
LEFT JOIN quizzes q ON q.document_id = d.id
WHERE q.created_at >= '2025-01-01';
-- Documents without 2025 quizzes are EXCLUDED (this effectively
-- becomes an INNER JOIN because WHERE filters out the NULLs)
```

**Question to think about:** You want to list all documents with the count of quizzes each one has, including documents that have zero quizzes. Should you use INNER JOIN or LEFT JOIN? And if you add `WHERE quiz_count > 0` later, what happens to your zero-quiz documents?

### Multiple JOINs

Real queries often join several tables. Read them left to right -- each JOIN adds more data to the working set:

```sql
-- Full picture: document -> quiz -> attempts -> user
SELECT
    d.title AS document_title,
    q.title AS quiz_title,
    u.username,
    qa.score,
    qa.completed_at
FROM documents d
JOIN quizzes q ON q.document_id = d.id
JOIN quiz_attempts qa ON qa.quiz_id = q.id
JOIN users u ON u.id = qa.user_id
ORDER BY qa.completed_at DESC;
```

---

## Chapter 6: Subqueries

A subquery is a query nested inside another query. They appear in three places: the SELECT list, the WHERE clause, and the FROM clause.

### Scalar Subqueries (Single Value)

A subquery that returns exactly one row and one column can be used anywhere a single value is expected:

```sql
SELECT
    title,
    score,
    score - (SELECT AVG(score) FROM quiz_attempts) AS above_average
FROM quiz_attempts qa
JOIN quizzes q ON q.id = qa.quiz_id;
```

### IN Subqueries

```sql
-- Documents that have at least one quiz
SELECT * FROM documents
WHERE id IN (SELECT document_id FROM quizzes);

-- Users who have never attempted a quiz
SELECT * FROM users
WHERE id NOT IN (
    SELECT DISTINCT user_id FROM quiz_attempts
);
```

**Pitfall with NOT IN:** If the subquery returns any NULL values, `NOT IN` returns no rows at all. This is because `x NOT IN (1, 2, NULL)` evaluates to `x != 1 AND x != 2 AND x != NULL`, and that last comparison is always unknown. Use `NOT EXISTS` instead for safety.

### EXISTS Subqueries

`EXISTS` checks whether the subquery returns any rows at all. It does not care about what data the rows contain -- it just checks for existence:

```sql
-- Documents that have at least one quiz (same result, different approach)
SELECT d.* FROM documents d
WHERE EXISTS (
    SELECT 1 FROM quizzes q WHERE q.document_id = d.id
);
```

`EXISTS` is almost always preferable to `IN` for this pattern. It short-circuits (stops as soon as it finds one matching row) and handles NULLs correctly.

### Correlated Subqueries

A correlated subquery references a column from the outer query, so it executes once per outer row:

```sql
-- Each user's most recent quiz attempt score
SELECT
    u.username,
    (
        SELECT qa.score
        FROM quiz_attempts qa
        WHERE qa.user_id = u.id
        ORDER BY qa.completed_at DESC
        LIMIT 1
    ) AS latest_score
FROM users u;
```

This is conceptually clear but can be slow for large datasets because the subquery runs for each row. Often rewritable with a JOIN or window function.

### CTEs (Common Table Expressions) with WITH

CTEs let you name a subquery and reference it like a table. They dramatically improve readability for complex queries:

```sql
-- Find quizzes where the average score is below the overall average
WITH overall AS (
    SELECT AVG(score) AS avg_score
    FROM quiz_attempts
),
quiz_averages AS (
    SELECT
        quiz_id,
        AVG(score) AS avg_score,
        COUNT(*) AS attempt_count
    FROM quiz_attempts
    GROUP BY quiz_id
)
SELECT
    q.title,
    qa.avg_score,
    qa.attempt_count,
    o.avg_score AS overall_avg
FROM quiz_averages qa
JOIN quizzes q ON q.id = qa.quiz_id
CROSS JOIN overall o
WHERE qa.avg_score < o.avg_score
ORDER BY qa.avg_score;
```

In SQLAlchemy, CTEs are first-class:

```python
overall = select(func.avg(QuizAttempt.score).label('avg_score')).cte('overall')
```

### Recursive CTEs

Recursive CTEs can traverse hierarchical data. Imagine documents having a `parent_id` for nested categories:

```sql
-- If documents had a parent_id column for hierarchy:
WITH RECURSIVE doc_tree AS (
    -- Base case: root documents (no parent)
    SELECT id, title, 0 AS depth
    FROM documents
    WHERE parent_id IS NULL

    UNION ALL

    -- Recursive case: children of documents already found
    SELECT d.id, d.title, dt.depth + 1
    FROM documents d
    JOIN doc_tree dt ON dt.id = d.parent_id
)
SELECT * FROM doc_tree ORDER BY depth, title;
```

```
+================================================================+
|                  RECURSIVE CTE EXECUTION                        |
+================================================================+
|                                                                  |
|  Iteration 0 (base case):                                       |
|  Find all roots --> {Doc A, Doc B}                               |
|       |                                                          |
|       v                                                          |
|  Iteration 1 (recursive):                                        |
|  Find children of {Doc A, Doc B} --> {Doc A1, Doc A2, Doc B1}    |
|       |                                                          |
|       v                                                          |
|  Iteration 2 (recursive):                                        |
|  Find children of {Doc A1, Doc A2, Doc B1} --> {Doc A1a}         |
|       |                                                          |
|       v                                                          |
|  Iteration 3: no children found --> STOP                         |
|                                                                  |
|  Final result = union of all iterations                          |
|                                                                  |
+================================================================+
```

**Question to think about:** What happens if your data has a cycle (Doc A is parent of Doc B, and Doc B is parent of Doc A)? How would you prevent an infinite loop in a recursive CTE?

---

## Chapter 7: Window Functions

Window functions perform calculations across a set of rows that are related to the current row -- without collapsing them into a single output row like aggregates do. This is the key difference: `GROUP BY` + `AVG()` gives you one row per group. A window function gives you the average *alongside every row*.

```
+================================================================+
|              AGGREGATE vs. WINDOW FUNCTION                       |
+================================================================+
|                                                                  |
|  Raw data:                                                       |
|  +--------+-------+                                              |
|  | quiz_id| score |                                              |
|  +--------+-------+                                              |
|  |   1    |  85   |                                              |
|  |   1    |  90   |                                              |
|  |   1    |  75   |                                              |
|  |   2    |  60   |                                              |
|  |   2    |  80   |                                              |
|  +--------+-------+                                              |
|                                                                  |
|  GROUP BY + AVG(score):         Window AVG(score) OVER:          |
|  +--------+-----+              +--------+-------+-----+          |
|  |quiz_id | avg |              |quiz_id | score | avg |          |
|  +--------+-----+              +--------+-------+-----+          |
|  |   1    |83.3 |              |   1    |  85   |83.3 |          |
|  |   2    |70.0 |              |   1    |  90   |83.3 |          |
|  +--------+-----+              |   1    |  75   |83.3 |          |
|  2 rows                        |   2    |  60   |70.0 |          |
|                                 |   2    |  80   |70.0 |          |
|                                 +--------+-------+-----+          |
|                                 5 rows (original rows kept)       |
|                                                                  |
+================================================================+
```

### The OVER Clause

Every window function requires `OVER(...)`. What goes inside the parentheses controls the "window" of rows the function sees:

```sql
SELECT
    quiz_id,
    user_id,
    score,
    AVG(score) OVER () AS overall_avg,                       -- all rows
    AVG(score) OVER (PARTITION BY quiz_id) AS quiz_avg,      -- per quiz
    AVG(score) OVER (PARTITION BY user_id) AS user_avg       -- per user
FROM quiz_attempts;
```

### Ranking Functions

```sql
SELECT
    quiz_id,
    user_id,
    score,
    ROW_NUMBER() OVER (PARTITION BY quiz_id ORDER BY score DESC) AS row_num,
    RANK()       OVER (PARTITION BY quiz_id ORDER BY score DESC) AS rank,
    DENSE_RANK() OVER (PARTITION BY quiz_id ORDER BY score DESC) AS dense_rank
FROM quiz_attempts;
```

```
+================================================================+
|              ROW_NUMBER vs. RANK vs. DENSE_RANK                  |
+================================================================+
|                                                                  |
|  Scores for quiz 1: 95, 90, 90, 85                              |
|                                                                  |
|  +-------+------------+------+------------+                      |
|  | score | ROW_NUMBER | RANK | DENSE_RANK |                      |
|  +-------+------------+------+------------+                      |
|  |  95   |     1      |   1  |     1      |                      |
|  |  90   |     2      |   2  |     2      |  <-- tied scores     |
|  |  90   |     3      |   2  |     2      |  <-- tied scores     |
|  |  85   |     4      |   4  |     3      |                      |
|  +-------+------------+------+------------+                      |
|                                                                  |
|  ROW_NUMBER: always unique, arbitrary tiebreak                   |
|  RANK:       ties get same rank, then skips (1,2,2,4)           |
|  DENSE_RANK: ties get same rank, no skip (1,2,2,3)              |
|                                                                  |
+================================================================+
```

### LAG and LEAD

Access values from previous or next rows without a self-join:

```sql
-- Compare each attempt to the user's previous attempt
SELECT
    user_id,
    quiz_id,
    score,
    completed_at,
    LAG(score) OVER (
        PARTITION BY user_id
        ORDER BY completed_at
    ) AS previous_score,
    score - LAG(score) OVER (
        PARTITION BY user_id
        ORDER BY completed_at
    ) AS improvement
FROM quiz_attempts;
```

`LAG(score, 1)` looks back 1 row (default). `LAG(score, 2)` looks back 2 rows. `LEAD` looks forward.

### Running Totals and Moving Averages (Frame Clauses)

The frame clause defines exactly which rows relative to the current row the window function considers:

```sql
-- Running total of attempts per user
SELECT
    user_id,
    completed_at,
    score,
    SUM(score) OVER (
        PARTITION BY user_id
        ORDER BY completed_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total,
    AVG(score) OVER (
        PARTITION BY user_id
        ORDER BY completed_at
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3
FROM quiz_attempts;
```

```
+================================================================+
|                    FRAME CLAUSE CHEAT SHEET                       |
+================================================================+
|                                                                  |
|  Given rows: [A] [B] [C] [D*] [E] [F] [G]                      |
|                          ^ current row                           |
|                                                                  |
|  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW               |
|     --> [A] [B] [C] [D*]                                        |
|     "Everything from the start up to here"                       |
|                                                                  |
|  ROWS BETWEEN 2 PRECEDING AND CURRENT ROW                       |
|     --> [B] [C] [D*]                                             |
|     "Last 3 rows including current"                              |
|                                                                  |
|  ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING               |
|     --> [D*] [E] [F] [G]                                        |
|     "Current row to the end"                                     |
|                                                                  |
|  ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING                       |
|     --> [C] [D*] [E]                                             |
|     "Immediate neighbors"                                        |
|                                                                  |
+================================================================+
```

**Question to think about:** You want to show each user their score percentile rank within each quiz (e.g., "you scored better than 80% of participants"). Which window function would you use? (Hint: look up `PERCENT_RANK` or `CUME_DIST`.)

---

## Chapter 8: Set Operations

Set operations combine the results of two or more queries.

### UNION, INTERSECT, EXCEPT

```sql
-- All unique document titles and quiz titles combined
SELECT title FROM documents
UNION
SELECT title FROM quizzes;

-- UNION ALL keeps duplicates (faster, no dedup step)
SELECT title FROM documents
UNION ALL
SELECT title FROM quizzes;

-- Titles that appear in both tables
SELECT title FROM documents
INTERSECT
SELECT title FROM quizzes;

-- Document titles that are NOT also quiz titles
SELECT title FROM documents
EXCEPT
SELECT title FROM quizzes;
```

**Rules:**
1. Both queries must return the same number of columns
2. Corresponding columns must have compatible types
3. Column names come from the first query
4. `UNION` / `INTERSECT` / `EXCEPT` deduplicate by default; add `ALL` to keep duplicates

A practical use case in MarkedQuiz -- combining different notification sources into a single timeline:

```sql
-- Recent activity feed
SELECT 'document_created' AS event_type, title AS description, created_at
FROM documents
WHERE created_at > now() - INTERVAL '7 days'

UNION ALL

SELECT 'quiz_completed', q.title || ' - Score: ' || qa.score::TEXT, qa.completed_at
FROM quiz_attempts qa
JOIN quizzes q ON q.id = qa.quiz_id
WHERE qa.completed_at > now() - INTERVAL '7 days'

ORDER BY created_at DESC
LIMIT 20;
```

---

## Chapter 9: INSERT, UPDATE, DELETE

### INSERT Basics

```sql
-- Single row
INSERT INTO documents (title, content)
VALUES ('PostgreSQL Lesson', '# PostgreSQL\n\nLearn queries...');

-- Multiple rows
INSERT INTO tags (name)
VALUES ('postgresql'), ('sql'), ('database'), ('backend');

-- Insert from a query
INSERT INTO document_tags (document_id, tag_id)
SELECT d.id, t.id
FROM documents d
CROSS JOIN tags t
WHERE d.title ILIKE '%postgresql%'
  AND t.name = 'postgresql';
```

### RETURNING

PostgreSQL's RETURNING clause gives you back data from the rows you just modified. This eliminates the need for a separate SELECT after an INSERT:

```sql
INSERT INTO documents (title, content)
VALUES ('New Lesson', '# Content here')
RETURNING id, created_at;
```

This is extremely useful in application code. In FastAPI, you insert a record and immediately need its generated `id` to return in the API response:

```python
# SQLAlchemy equivalent
stmt = (
    insert(Document)
    .values(title="New Lesson", content="# Content here")
    .returning(Document.id, Document.created_at)
)
result = await session.execute(stmt)
```

RETURNING works on INSERT, UPDATE, and DELETE.

### INSERT ON CONFLICT (Upsert)

"Insert this row, but if it conflicts with a unique constraint, update instead":

```sql
-- Insert a tag, or if the name already exists, do nothing
INSERT INTO tags (name)
VALUES ('postgresql')
ON CONFLICT (name) DO NOTHING;

-- Insert a quiz attempt, or if it conflicts, update the score
-- (assuming a unique constraint on (quiz_id, user_id))
INSERT INTO quiz_attempts (quiz_id, user_id, score)
VALUES (1, 5, 92)
ON CONFLICT (quiz_id, user_id)
DO UPDATE SET
    score = EXCLUDED.score,
    completed_at = now()
WHERE EXCLUDED.score > quiz_attempts.score;  -- only update if new score is higher
```

`EXCLUDED` refers to the row that was proposed for insertion. The `WHERE` clause on `DO UPDATE` lets you conditionally update -- here, only if the new score is an improvement.

### UPDATE

```sql
-- Simple update
UPDATE documents
SET updated_at = now()
WHERE id = 5;

-- Update with expression
UPDATE quiz_attempts
SET score = LEAST(score + 5, 100)  -- bonus points, capped at 100
WHERE quiz_id = 3;

-- Update from another table (PostgreSQL extension)
UPDATE quizzes
SET title = d.title || ' Quiz'
FROM documents d
WHERE d.id = quizzes.document_id
  AND quizzes.title IS NULL;
```

### DELETE

```sql
-- Simple delete
DELETE FROM quiz_attempts
WHERE completed_at < '2024-01-01';

-- Delete with a subquery
DELETE FROM documents
WHERE id NOT IN (
    SELECT DISTINCT document_id FROM quizzes
);

-- Delete with RETURNING (get back what you deleted)
DELETE FROM quiz_attempts
WHERE score < 20
RETURNING id, user_id, score;
```

### CTEs in Write Queries

PostgreSQL lets you use CTEs with INSERT, UPDATE, and DELETE. This enables powerful multi-step operations in a single query:

```sql
-- Archive old attempts: delete them and insert into an archive table
WITH deleted AS (
    DELETE FROM quiz_attempts
    WHERE completed_at < '2024-01-01'
    RETURNING *
)
INSERT INTO quiz_attempts_archive
SELECT * FROM deleted;
```

```sql
-- Create a quiz for every document that doesn't have one yet
WITH docs_without_quizzes AS (
    SELECT d.id, d.title
    FROM documents d
    LEFT JOIN quizzes q ON q.document_id = d.id
    WHERE q.id IS NULL
)
INSERT INTO quizzes (document_id, title)
SELECT id, title || ' - Auto Quiz'
FROM docs_without_quizzes
RETURNING id, document_id, title;
```

**Question to think about:** Your FastAPI endpoint for creating a document also needs to insert tags and link them in `document_tags`. Could you do all three operations (insert document, insert tags, insert junction rows) in a single SQL statement using CTEs? What are the trade-offs vs. doing it in three separate statements inside a SQLAlchemy transaction?

---

## Chapter 10: Query Planning and Performance

### EXPLAIN ANALYZE

This is your single most important tool for understanding query performance:

```sql
EXPLAIN ANALYZE
SELECT d.title, COUNT(q.id) AS quiz_count
FROM documents d
LEFT JOIN quizzes q ON q.document_id = d.id
GROUP BY d.id, d.title;
```

```
+================================================================+
|                  READING EXPLAIN ANALYZE OUTPUT                   |
+================================================================+
|                                                                  |
|  HashAggregate (cost=35.50..37.50 rows=200 width=40)            |
|    -> Hash Left Join (cost=12.00..30.50 rows=500 width=36)      |
|         Hash Cond: (d.id = q.document_id)                        |
|         -> Seq Scan on documents d (cost=0.00..15.00 rows=500)  |
|         -> Hash (cost=8.00..8.00 rows=200 width=8)              |
|              -> Seq Scan on quizzes q (cost=0.00..8.00 rows=200)|
|                                                                  |
|  Key numbers to look at:                                         |
|                                                                  |
|  cost=START..TOTAL  Estimated cost (arbitrary units)             |
|  rows=N             Estimated row count                          |
|  actual time=X..Y   Real execution time in milliseconds          |
|  actual rows=N      Real row count                               |
|  loops=N            How many times this node executed             |
|                                                                  |
|  ACTUAL vs ESTIMATED rows being very different means             |
|  the planner has bad statistics --> run ANALYZE on the table.    |
|                                                                  |
+================================================================+
```

### Sequential Scan vs. Index Scan

```
+================================================================+
|              SCAN TYPE DECISION                                   |
+================================================================+
|                                                                  |
|  Sequential Scan (Seq Scan):                                     |
|  Read EVERY row in the table, check each one                     |
|  [row1] [row2] [row3] [row4] [row5] ... [rowN]                  |
|  Good when: selecting large % of table, small table              |
|                                                                  |
|  Index Scan:                                                     |
|  Look up matching rows via the index, then fetch from table      |
|    Index: { key -> row_location }                                |
|    Jump directly to [row3] and [row7]                            |
|  Good when: selecting small % of table (<10-15%)                 |
|                                                                  |
|  Index Only Scan:                                                |
|  All needed columns are IN the index -- no table fetch needed    |
|  The fastest possible scan                                       |
|                                                                  |
|  Bitmap Index Scan:                                              |
|  Build a bitmap of matching rows from the index, then fetch      |
|  Good when: selecting moderate % (10-30%) of table               |
|  Also good when: combining multiple indexes with AND/OR          |
|                                                                  |
+================================================================+
```

### When Indexes Help (and When They Don't)

```sql
-- Index on quiz_attempts(user_id) helps here:
SELECT * FROM quiz_attempts WHERE user_id = 42;

-- Index on quiz_attempts(score) probably does NOT help:
SELECT * FROM quiz_attempts WHERE score > 50;
-- (If most scores are > 50, PostgreSQL prefers a seq scan)

-- Expression indexes for case-insensitive search:
CREATE INDEX idx_documents_title_lower ON documents (LOWER(title));
SELECT * FROM documents WHERE LOWER(title) = 'postgresql lesson';

-- Partial indexes for common filters:
CREATE INDEX idx_recent_attempts ON quiz_attempts (completed_at)
WHERE completed_at > '2025-01-01';
-- Only indexes recent rows, smaller and faster
```

### Common Performance Pitfalls

| Pitfall | What Happens | Fix |
|---------|-------------|-----|
| Missing FK index | JOINs do sequential scans | `CREATE INDEX ON quizzes(document_id)` |
| `LIKE '%term%'` | Can't use B-tree index | Use `pg_trgm` + GIN index, or full-text search |
| `DISTINCT` on large results | Expensive deduplication | Check if the query logic naturally avoids duplicates |
| `SELECT *` through ORM | Fetches columns you don't need | Select only needed columns |
| N+1 queries | 1 query for list + N queries for details | Use JOINs or `selectinload()` in SQLAlchemy |
| Function on indexed column | `WHERE UPPER(title) = 'X'` bypasses index on `title` | Create expression index or match the index form |
| Implicit type casts | `WHERE id = '5'` may prevent index use | Use matching types |
| Missing ANALYZE | Planner uses default statistics | Run `ANALYZE tablename` after bulk loads |

**Question to think about:** Your MarkedQuiz API has an endpoint that lists all documents with their quiz count and average score. If you have 10,000 documents, 50,000 quizzes, and 1,000,000 quiz attempts, how would you structure the query and indexes to keep this endpoint fast? Think about which JOINs are necessary and where indexes would help.

---

## Chapter 11: Practical Patterns

### Pattern 1: Keyset Pagination for API Endpoints

```sql
-- First page
SELECT id, title, created_at
FROM documents
ORDER BY created_at DESC, id DESC
LIMIT 20;

-- Next page (using last row's values as cursor)
SELECT id, title, created_at
FROM documents
WHERE (created_at, id) < ('2025-03-15T10:30:00Z', 142)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

The `(created_at, id) <` syntax is a **row comparison** -- it compares tuples lexicographically. Including `id` in the comparison handles ties in `created_at`.

### Pattern 2: Search with Ranking

```sql
-- Full-text search with relevance ranking
SELECT
    id,
    title,
    ts_rank(to_tsvector('english', content), plainto_tsquery('english', 'postgresql index')) AS rank
FROM documents
WHERE to_tsvector('english', content) @@ plainto_tsquery('english', 'postgresql index')
ORDER BY rank DESC
LIMIT 10;

-- Requires a GIN index for performance:
-- CREATE INDEX idx_documents_fts ON documents USING GIN (to_tsvector('english', content));
```

### Pattern 3: Soft Deletes

Instead of actually deleting rows, mark them as deleted:

```sql
-- Add a deleted_at column
ALTER TABLE documents ADD COLUMN deleted_at TIMESTAMPTZ;

-- "Delete" a document
UPDATE documents SET deleted_at = now() WHERE id = 5;

-- Normal queries exclude deleted rows
SELECT * FROM documents WHERE deleted_at IS NULL;

-- Create a partial index for the common case
CREATE INDEX idx_documents_active ON documents (created_at)
WHERE deleted_at IS NULL;

-- Actually purge old deleted records periodically
DELETE FROM documents
WHERE deleted_at < now() - INTERVAL '90 days';
```

### Pattern 4: Audit Trail with CTEs

```sql
-- Update a document and log the change
WITH old_version AS (
    SELECT id, title, content, updated_at
    FROM documents
    WHERE id = 5
),
updated AS (
    UPDATE documents
    SET content = 'New content here', updated_at = now()
    WHERE id = 5
    RETURNING id, title, content, updated_at
)
INSERT INTO document_audit_log (document_id, old_content, new_content, changed_at)
SELECT
    o.id,
    o.content,
    u.content,
    u.updated_at
FROM old_version o
JOIN updated u ON u.id = o.id;
```

### Pattern 5: JSONB Queries

If your documents table has a `metadata JSONB` column:

```sql
-- Query JSON fields
SELECT title, metadata->>'author' AS author
FROM documents
WHERE metadata->>'category' = 'tutorial';

-- Check if a key exists
SELECT * FROM documents
WHERE metadata ? 'tags';

-- Query nested arrays
SELECT * FROM documents
WHERE metadata @> '{"tags": ["postgresql"]}';

-- GIN index for JSONB
CREATE INDEX idx_documents_metadata ON documents USING GIN (metadata);
```

### Pattern 6: Statistics Dashboard Query

Combining multiple concepts into a real-world query:

```sql
WITH user_stats AS (
    SELECT
        u.id AS user_id,
        u.username,
        COUNT(DISTINCT qa.quiz_id) AS quizzes_attempted,
        COUNT(qa.id) AS total_attempts,
        ROUND(AVG(qa.score), 1) AS avg_score,
        MAX(qa.score) AS best_score,
        MAX(qa.completed_at) AS last_active
    FROM users u
    LEFT JOIN quiz_attempts qa ON qa.user_id = u.id
    GROUP BY u.id, u.username
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY avg_score DESC NULLS LAST) AS score_rank,
        RANK() OVER (ORDER BY total_attempts DESC) AS activity_rank
    FROM user_stats
)
SELECT
    username,
    quizzes_attempted,
    total_attempts,
    avg_score,
    best_score,
    score_rank,
    activity_rank,
    last_active
FROM ranked
ORDER BY score_rank;
```

---

## Chapter 12: Exercises

Work through these in order. Each builds on concepts from the previous ones.

### Exercise 1: Basic SELECT and Filtering

Write a query that finds all documents created in the last 30 days, showing only the `id`, `title`, and how many days old each document is (as a whole number). Sort by newest first.

*Hint: `now() - created_at` gives an interval. Use `EXTRACT(DAY FROM ...)` or cast to get a number.*

### Exercise 2: Aggregation with GROUP BY

Write a query that shows each quiz's title, the number of attempts, the average score (rounded to one decimal place), and the highest score. Only include quizzes that have been attempted at least 3 times. Sort by average score descending.

### Exercise 3: JOIN and LEFT JOIN

Write a query that lists ALL documents (even ones without quizzes), showing the document title and the count of quizzes for each document. Documents with zero quizzes should show `0`, not `NULL`.

*Hint: `COUNT(column)` counts non-NULLs. `COALESCE(value, 0)` replaces NULL with 0.*

### Exercise 4: Subquery with EXISTS

Write a query that finds all users who have attempted every quiz (i.e., there is no quiz that the user has not attempted). This is the "relational division" problem.

*Hint: Think about it with double negation -- find users where there does NOT EXIST a quiz that the user has NOT attempted.*

### Exercise 5: Window Functions -- Ranking

For each quiz, rank all attempts by score (highest first). Show the quiz title, username, score, and rank. Use `DENSE_RANK` so tied scores get the same rank. Then wrap the whole thing so it only returns the top 3 per quiz.

*Hint: You'll need a subquery or CTE because you can't filter directly on window function results in the WHERE clause.*

### Exercise 6: Window Functions -- LAG for Trend Analysis

Write a query that shows each user's quiz attempts in chronological order, along with their previous score and the difference (improvement or decline). Include only users who have made at least 5 attempts.

### Exercise 7: CTE with Write Operations

Write a single SQL statement that:
1. Finds all documents that have no quizzes
2. Creates a quiz for each one (titled "[document title] - Auto Generated Quiz")
3. Returns the newly created quizzes with their associated document titles

*Use a CTE chain: one CTE to find the documents, another to INSERT the quizzes with RETURNING, then SELECT the results.*

### Exercise 8: Complex Dashboard Query

Build a "user progress report" query that shows for each user:
- Username
- Total quizzes attempted (distinct)
- Total attempts
- Average score across all attempts
- Their percentile rank among all users (by average score)
- Their best single quiz performance (quiz title + score)
- Days since their last attempt

Use CTEs to break this into readable steps. Add an `EXPLAIN ANALYZE` to see how PostgreSQL executes it, and note which JOINs or scans you would optimize with indexes.

### Exercise 9: Keyset Pagination Implementation

Write two queries that implement keyset pagination for the documents list:
1. The first page query (newest 10 documents with their quiz count)
2. The "next page" query that accepts the last document's `created_at` and `id` as cursor values

Make sure documents with identical `created_at` timestamps are handled correctly (no skipped or duplicate rows).

### Exercise 10: Full-Text Search with Ranking

Write a query that searches documents by content using PostgreSQL full-text search. Return the title, a snippet of the matching content (using `ts_headline`), and a relevance score. Include the index creation statement needed to make this performant.

---

## Quick Reference Tables

### SQL Clause Execution Order

| Step | Clause | What It Does |
|------|--------|-------------|
| 1 | `FROM` / `JOIN` | Identify source tables and join them |
| 2 | `WHERE` | Filter individual rows |
| 3 | `GROUP BY` | Group rows for aggregation |
| 4 | `HAVING` | Filter groups |
| 5 | `SELECT` | Compute output expressions and window functions |
| 6 | `DISTINCT` | Remove duplicate rows |
| 7 | `ORDER BY` | Sort results |
| 8 | `LIMIT` / `OFFSET` | Restrict number of rows returned |

This order is why you cannot use a column alias from SELECT in your WHERE clause -- WHERE executes before SELECT.

### Aggregate Functions

| Function | Description | NULL Handling |
|----------|------------|---------------|
| `COUNT(*)` | Count all rows | Counts NULLs |
| `COUNT(col)` | Count non-NULL values | Ignores NULLs |
| `COUNT(DISTINCT col)` | Count unique non-NULL values | Ignores NULLs |
| `SUM(col)` | Sum of values | Ignores NULLs |
| `AVG(col)` | Average of values | Ignores NULLs |
| `MIN(col)` | Minimum value | Ignores NULLs |
| `MAX(col)` | Maximum value | Ignores NULLs |
| `ARRAY_AGG(col)` | Collect into array | Includes NULLs |
| `STRING_AGG(col, sep)` | Concatenate with separator | Ignores NULLs |
| `BOOL_AND(col)` | True if ALL true | Ignores NULLs |
| `BOOL_OR(col)` | True if ANY true | Ignores NULLs |

### JOIN Types Quick Reference

| JOIN Type | Keeps Left Unmatched | Keeps Right Unmatched |
|-----------|---------------------|----------------------|
| `INNER JOIN` | No | No |
| `LEFT JOIN` | Yes (NULLs for right) | No |
| `RIGHT JOIN` | No | Yes (NULLs for left) |
| `FULL OUTER JOIN` | Yes | Yes |
| `CROSS JOIN` | N/A (all combinations) | N/A |

### Window Function Quick Reference

| Function | Purpose |
|----------|---------|
| `ROW_NUMBER()` | Unique sequential integer per partition |
| `RANK()` | Rank with gaps for ties (1,2,2,4) |
| `DENSE_RANK()` | Rank without gaps (1,2,2,3) |
| `NTILE(n)` | Divide rows into n equal-ish buckets |
| `LAG(col, n)` | Value from n rows before current |
| `LEAD(col, n)` | Value from n rows after current |
| `FIRST_VALUE(col)` | First value in the window frame |
| `LAST_VALUE(col)` | Last value in the window frame |
| `PERCENT_RANK()` | Relative rank as 0-1 fraction |
| `CUME_DIST()` | Cumulative distribution (% of rows <= current) |

### Common Index Types

| Index Type | Best For | Example |
|-----------|---------|---------|
| B-tree (default) | Equality and range queries | `CREATE INDEX ON users(email)` |
| GIN | Full-text search, JSONB, arrays | `CREATE INDEX ON docs USING GIN(to_tsvector(...))` |
| GiST | Geometric data, range types, full-text | `CREATE INDEX ON events USING GiST(time_range)` |
| Hash | Equality only (no range) | `CREATE INDEX ON sessions USING HASH(token)` |
| BRIN | Large, naturally ordered tables | `CREATE INDEX ON logs USING BRIN(created_at)` |

---

## Questions

1. You write `SELECT title, LENGTH(content) AS content_length FROM documents WHERE content_length > 500;`. What happens?

   A) It works correctly, returning documents with content longer than 500 characters
   B) PostgreSQL returns an error because `WHERE` is evaluated before `SELECT`, so the alias `content_length` does not exist yet
   C) PostgreSQL silently ignores the alias and returns all rows
   D) The query runs but returns zero rows because aliases are always NULL in `WHERE`

2. What is the key difference between `WHERE d.id IN (SELECT ...)` and `WHERE EXISTS (SELECT ...)`?

   A) `IN` is always faster because it only runs the subquery once
   B) `EXISTS` checks if the subquery returns at least one row without comparing values, making it more reliable when the subquery might return NULLs
   C) `IN` and `EXISTS` are identical in behavior and performance -- the choice is purely stylistic
   D) `EXISTS` cannot be used with correlated subqueries

3. Given five quiz scores of 95, 90, 90, 85, 80, what does `RANK()` return for each?

   A) 1, 2, 2, 3, 4 -- tied values share a rank and the next rank increments by 1 (no gaps)
   B) 1, 2, 3, 4, 5 -- always unique, ties get arbitrary ordering
   C) 1, 2, 2, 4, 5 -- tied values share a rank but the next rank skips (gaps)
   D) 1, 1, 1, 2, 3 -- all scores above the median get rank 1

4. You run `EXPLAIN ANALYZE` and see `Seq Scan on documents (cost=0.00..35.50 rows=1550)`. What does "Seq Scan" mean?

   A) PostgreSQL is using a sequential index to quickly locate matching rows
   B) PostgreSQL is reading every row in the table sequentially -- it has no index shortcut for this query
   C) The query is running in a sequence of parallel workers for speed
   D) PostgreSQL is scanning only the first row of each page sequentially

5. Which `INSERT ... ON CONFLICT` statement correctly upserts a quiz score, updating only if the new score is higher?

   A) `INSERT INTO quiz_scores (user_id, quiz_id, score) VALUES (1, 5, 88) ON CONFLICT (user_id, quiz_id) DO UPDATE SET score = 88;`
   B) `INSERT INTO quiz_scores (user_id, quiz_id, score) VALUES (1, 5, 88) ON CONFLICT (user_id, quiz_id) DO UPDATE SET score = EXCLUDED.score WHERE EXCLUDED.score > quiz_scores.score;`
   C) `INSERT INTO quiz_scores (user_id, quiz_id, score) VALUES (1, 5, 88) ON CONFLICT DO NOTHING WHERE score < 88;`
   D) `INSERT INTO quiz_scores (user_id, quiz_id, score) VALUES (1, 5, 88) ON CONFLICT (user_id, quiz_id) DO REPLACE SET score = EXCLUDED.score;`

6. Your app loads documents, then makes a separate query per document to count quizzes (N+1 pattern). Which single query fixes this?

   A) `SELECT d.id, d.title, COUNT(q.id) FROM documents d INNER JOIN quizzes q ON q.document_id = d.id GROUP BY d.id, d.title;`
   B) `SELECT d.id, d.title, COUNT(q.id) FROM documents d LEFT JOIN quizzes q ON q.document_id = d.id GROUP BY d.id, d.title;`
   C) `SELECT d.id, d.title, (SELECT COUNT(*) FROM quizzes) FROM documents d;`
   D) `SELECT d.id, d.title, COUNT(*) FROM documents d, quizzes q GROUP BY d.id;`

7. What does a CTE (`WITH` clause) do?

   A) It creates a permanent table that persists after the query finishes
   B) It creates a named temporary result set that exists only for the duration of the query, improving readability by breaking complex logic into named steps
   C) It caches the result of a query permanently in memory for faster future lookups
   D) It is an alias for `CREATE TEMPORARY TABLE` and requires explicit cleanup

8. Why is keyset pagination better than `OFFSET` pagination for large tables?

   A) Keyset pagination returns results faster because it skips the `ORDER BY` step
   B) `OFFSET` requires the database to scan and discard all skipped rows, while keyset pagination uses an index to jump directly to the right position
   C) Keyset pagination does not require any indexes, unlike `OFFSET`
   D) `OFFSET` is deprecated in PostgreSQL 16 and later versions

## Answers Hidden

1. **B** — `WHERE` is evaluated at Step 2 of PostgreSQL's execution pipeline, before `SELECT` (Step 5) where the alias is defined. You must repeat the expression: `WHERE LENGTH(content) > 500`. Note that `ORDER BY` can use the alias because it executes after `SELECT`.

2. **B** — `EXISTS` only checks whether the subquery returns at least one row, never comparing values directly. If the subquery returns NULLs, `IN` can produce NULL (unknown) instead of FALSE, silently dropping rows from results. Prefer `EXISTS` for correlated subqueries.

3. **C** — `RANK()` gives tied values the same rank but leaves gaps: 1, 2, 2, 4, 5. Compare with `ROW_NUMBER()` (1,2,3,4,5 -- always unique) and `DENSE_RANK()` (1,2,2,3,4 -- no gaps). Use `RANK` when gaps should reflect ties, such as "3rd place" reflecting that two people tied for 2nd.

4. **B** — "Seq Scan" means PostgreSQL reads every row sequentially with no index shortcut. For small tables this is fine, but it becomes expensive around 10,000+ rows. Fix it by creating an index on the filtered column and verify with `EXPLAIN ANALYZE` showing `Index Scan` instead.

5. **B** — The `EXCLUDED` keyword refers to the proposed insertion row. The `WHERE EXCLUDED.score > quiz_scores.score` clause ensures the update only happens when the new score is higher. Option A always overwrites, and `DO REPLACE` (option D) is not valid PostgreSQL syntax.

6. **B** — `LEFT JOIN` is necessary because `INNER JOIN` would exclude documents with zero quizzes (no matching row in the quizzes table). With `LEFT JOIN`, those documents still appear and `COUNT(q.id)` correctly returns 0 since it counts non-NULL values.

7. **B** — A CTE creates a named temporary result set scoped to a single query. It improves readability by breaking complex logic into named, independently testable steps rather than deeply nested subqueries. It does not persist after the query finishes.

8. **B** — `OFFSET` must scan and discard all skipped rows (e.g., `OFFSET 10000` reads 10,000 rows to throw away). Keyset pagination uses the last row's values as a cursor and leverages an index to jump directly to the right position, staying fast regardless of how deep into the result set you are.

---

## Summary Checklist

Before you consider yourself comfortable with PostgreSQL queries, make sure you can answer YES to all of these:

- [ ] I can write SELECT with expressions, aliases, and CASE without looking up syntax
- [ ] I understand why `WHERE column = NULL` doesn't work and use `IS NULL` instead
- [ ] I know the difference between WHERE and HAVING and when each applies
- [ ] I can draw the result of INNER, LEFT, RIGHT, and FULL OUTER JOINs given sample data
- [ ] I understand why LEFT JOIN conditions in ON vs. WHERE produce different results
- [ ] I can use EXISTS instead of IN for subqueries and know why it handles NULLs better
- [ ] I can write a CTE (WITH clause) to break complex queries into readable steps
- [ ] I understand the difference between ROW_NUMBER, RANK, and DENSE_RANK
- [ ] I can use LAG/LEAD to compare a row with its neighbors
- [ ] I know what a frame clause does and can write a running total with SUM OVER
- [ ] I can use INSERT ON CONFLICT for upsert operations
- [ ] I use RETURNING on INSERT/UPDATE/DELETE to avoid extra round trips
- [ ] I can read EXPLAIN ANALYZE output and identify sequential scans on large tables
- [ ] I know when OFFSET pagination becomes a problem and can implement keyset pagination
- [ ] I understand which queries benefit from indexes and which don't
- [ ] I can spot N+1 query patterns in ORM code and fix them with proper JOINs or eager loading

---

*Next lesson: PostgreSQL Schema Design -- normalization, denormalization trade-offs, constraint design, migration strategies, and how schema choices affect the queries you write.*
