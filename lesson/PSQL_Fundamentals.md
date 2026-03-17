# The SQL Language: PostgreSQL Tutorial Chapter 2

**Category:** PostgreSQL -- SQL Fundamentals
**Subcategory:** DDL, DML, Queries, Joins, Aggregates
**Prerequisites:** PostgreSQL installed, `psql` basics, a database named `mydb` created

---

## The Big Picture

SQL is the language you use to talk to a relational database. This lesson covers the complete lifecycle of data in PostgreSQL -- creating tables, inserting rows, querying with filters and joins, aggregating results, and modifying or deleting data. Everything here uses two small tables: `weather` and `cities`.

```
+=====================================================================+
|                   THE SQL DATA LIFECYCLE                              |
+=====================================================================+
|                                                                      |
|  1. CREATE TABLE     Define the structure (schema)                   |
|        |                                                             |
|        v                                                             |
|  2. INSERT INTO      Populate with rows of data                      |
|        |                                                             |
|        v                                                             |
|  3. SELECT ... FROM  Query: read and combine data                    |
|        |                                                             |
|        v                                                             |
|  4. UPDATE           Modify existing rows                            |
|        |                                                             |
|        v                                                             |
|  5. DELETE           Remove rows                                     |
|        |                                                             |
|        v                                                             |
|  6. DROP TABLE       Remove the entire table                         |
|                                                                      |
+=====================================================================+
```

By the end, you will be able to write any basic SQL query against PostgreSQL and understand exactly what the database does with it.

---

## Chapter 1: Relational Concepts -- What Is a Table?

PostgreSQL is a **relational database management system** (RDBMS). The word "relational" comes from mathematics -- a "relation" is formally what we call a **table**.

A table is a named collection of **rows**. Every row in a given table has the same set of named **columns**, and each column has a specific **data type**.

```
+=====================================================================+
|                    THE RELATIONAL MODEL                               |
+=====================================================================+
|                                                                      |
|  TABLE: weather                                                      |
|  +----------+---------+---------+------+------------+                |
|  | city     | temp_lo | temp_hi | prcp | date       |  <-- COLUMNS  |
|  | varchar  | int     | int     | real | date       |  <-- TYPES    |
|  +==========+=========+=========+======+============+                |
|  | San Fran |      46 |      50 | 0.25 | 1994-11-27 |  <-- ROW 1   |
|  | San Fran |      43 |      57 |  0.0 | 1994-11-29 |  <-- ROW 2   |
|  | Hayward  |      37 |      54 |      | 1994-11-29 |  <-- ROW 3   |
|  +----------+---------+---------+------+------------+                |
|                                                                      |
|  Columns have a FIXED ORDER in each row.                             |
|  Rows have NO guaranteed order -- you must ORDER BY explicitly.      |
|                                                                      |
+=====================================================================+
```

Key hierarchy: rows live in **tables**, tables live in **databases**, and a collection of databases managed by one PostgreSQL server instance is called a **database cluster**.

**Question to think about:** If rows have no guaranteed order, what does that mean for your application code? If you run the same `SELECT` query twice without `ORDER BY`, could you get the rows back in a different sequence each time?

---

## Chapter 2: Creating a New Table

Use `CREATE TABLE` to define a table's structure:

```sql
CREATE TABLE weather (
    city        varchar(80),
    temp_lo     int,           -- low temperature
    temp_hi     int,           -- high temperature
    prcp        real,          -- precipitation
    date        date
);

CREATE TABLE cities (
    name        varchar(80),
    location    point          -- PostgreSQL-specific type
);
```

Some things to notice:

- **Whitespace is free-form.** You can write the entire statement on one line or spread it across many. PostgreSQL does not care.
- **`--` starts a comment** that runs to the end of the line.
- **SQL is case-insensitive** for keywords and identifiers. `CREATE TABLE`, `create table`, and `Create Table` all work the same. The exception: if you double-quote an identifier (`"MyTable"`), case is preserved exactly.
- **`point` is a PostgreSQL extension.** Standard SQL does not define it. PostgreSQL supports many types beyond the standard, including geometric types and user-defined types.

### Common Data Types

| Type | What It Stores | Example |
|------|---------------|---------|
| `int` | Whole numbers | `46` |
| `smallint` | Smaller whole numbers (2 bytes) | `100` |
| `real` | Floating-point (4 bytes) | `0.25` |
| `double precision` | Floating-point (8 bytes) | `3.14159265` |
| `char(N)` | Fixed-length string, padded | `'CA'` |
| `varchar(N)` | Variable-length string, max N | `'San Francisco'` |
| `date` | Calendar date | `'1994-11-27'` |
| `time` | Time of day | `'14:30:00'` |
| `timestamp` | Date + time | `'1994-11-27 14:30:00'` |
| `interval` | Time span | `'1 hour 30 minutes'` |
| `point` | 2D coordinate (PostgreSQL-specific) | `'(-194.0, 53.0)'` |

To remove a table entirely:

```sql
DROP TABLE weather;
```

**Cross-stack connection:** In SQLAlchemy, `CREATE TABLE` maps to your model class definition. Each column in SQL becomes a `Column()` in the model:

```
  SQL                              SQLAlchemy
  ---                              ----------
  city varchar(80)        -->      city = Column(String(80))
  temp_lo int             -->      temp_lo = Column(Integer)
  prcp real               -->      prcp = Column(Float)
  date date               -->      date = Column(Date)
```

---

## Chapter 3: Populating a Table With Rows

### INSERT Basics

```sql
INSERT INTO weather VALUES ('San Francisco', 46, 50, 0.25, '1994-11-27');
```

Rules:
- Non-numeric constants (strings, dates) must use **single quotes**. Double quotes are for identifiers.
- Values must appear in the **same order as the columns** were declared in `CREATE TABLE`.
- The `point` type takes a string representation: `'(-194.0, 53.0)'`.

```sql
INSERT INTO cities VALUES ('San Francisco', '(-194.0, 53.0)');
```

### Explicit Column Lists (Best Practice)

Instead of relying on column order, list the columns explicitly:

```sql
INSERT INTO weather (city, temp_lo, temp_hi, prcp, date)
    VALUES ('San Francisco', 43, 57, 0.0, '1994-11-29');

INSERT INTO weather (date, city, temp_hi, temp_lo)
    VALUES ('1994-11-29', 'Hayward', 54, 37);
```

Notice: in the second insert, columns are reordered and `prcp` is omitted entirely (it gets NULL). This is why explicit column lists are best practice -- your INSERT statements survive column reordering and additions to the table.

**Cross-stack connection:** In SQLAlchemy, `INSERT INTO` maps to `session.add(obj)`. The explicit column names are handled automatically by the ORM -- another reason to prefer it for application code.

### Bulk Loading With COPY

For loading large volumes of data from flat files, `COPY` is much faster than many `INSERT` statements:

```sql
COPY weather FROM '/home/user/weather.txt';
```

The file must be accessible on the **server** machine (not your local client). Default format is tab-separated with `\N` representing NULL values.

**Question to think about:** Why does `COPY` require the file to be on the server? Think about where the PostgreSQL process runs versus where `psql` runs. What security implications would there be if `COPY` could read files from the client machine by default?

---

## Chapter 4: Querying a Table

### The Basics of SELECT

Retrieve all columns, all rows:

```sql
SELECT * FROM weather;
```

Using `*` means "all columns." This is convenient for exploration but **bad practice in production code** -- if someone adds a column to the table, your query suddenly returns extra data.

Explicit column list:

```sql
SELECT city, temp_lo, temp_hi, prcp, date FROM weather;
```

### Expressions and Column Aliases

You can compute values in the select list:

```sql
SELECT city, (temp_hi + temp_lo) / 2 AS temp_avg, date FROM weather;
```

The `AS` keyword gives the computed column a name. Without it, PostgreSQL assigns a generated name like `?column?`. The `AS` keyword itself is optional -- `(temp_hi + temp_lo) / 2 temp_avg` works too -- but including it is clearer.

### Filtering With WHERE

```sql
SELECT * FROM weather
    WHERE city = 'San Francisco' AND prcp > 0.0;
```

The `WHERE` clause contains a Boolean expression. Only rows where the expression evaluates to true are returned. You can combine conditions with `AND`, `OR`, and `NOT`.

### Sorting With ORDER BY

```sql
SELECT * FROM weather ORDER BY city;
```

Multi-column sort:

```sql
SELECT * FROM weather ORDER BY city, temp_lo;
```

Without `ORDER BY`, the database returns rows in whatever order is most convenient internally. Never assume order without asking for it.

### Removing Duplicates With DISTINCT

```sql
SELECT DISTINCT city FROM weather;
```

`DISTINCT` does **not** guarantee any particular order. For consistent, duplicate-free results, combine both:

```sql
SELECT DISTINCT city FROM weather ORDER BY city;
```

**Cross-stack connection:** In SQLAlchemy:

```
  SQL                                  SQLAlchemy
  ---                                  ----------
  SELECT * FROM weather                session.query(Weather).all()
  WHERE city = 'San Francisco'  -->    .filter(Weather.city == 'San Francisco')
  ORDER BY city                 -->    .order_by(Weather.city)
  DISTINCT city                 -->    session.query(Weather.city).distinct()
```

**Question to think about:** What happens if you write `ORDER BY temp_lo` on a table with millions of rows and no index on `temp_lo`? How does the database actually sort -- does it need to read every row first?

---

## Chapter 5: Joins Between Tables

A **join** combines rows from two (or more) tables based on a related column. This is the heart of the relational model -- data is split across normalized tables and reassembled at query time.

### Inner Join

```sql
SELECT * FROM weather JOIN cities ON city = name;
```

This matches each weather row with the cities row where `weather.city` equals `cities.name`.

```
+=====================================================================+
|                     HOW INNER JOIN WORKS                              |
+=====================================================================+
|                                                                      |
|  weather table                    cities table                       |
|  +---------------+------+         +---------------+-----------+      |
|  | city          | ...  |         | name          | location  |      |
|  +===============+======+         +===============+===========+      |
|  | San Francisco | ...  | ------> | San Francisco | (-194,53) |  OK  |
|  | San Francisco | ...  | ------> | San Francisco | (-194,53) |  OK  |
|  | Hayward       | ...  | --X-->  |               |           |  NO  |
|  +---------------+------+    |    +---------------+-----------+      |
|                              |                                       |
|                    No matching row in cities!                         |
|                    Hayward is EXCLUDED from results.                  |
|                                                                      |
|  RESULT (3 columns shown):                                           |
|  +---------------+-----------+------+                                |
|  | city          | location  | ...  |                                |
|  +===============+===========+======+                                |
|  | San Francisco | (-194,53) | ...  |                                |
|  | San Francisco | (-194,53) | ...  |                                |
|  +---------------+-----------+------+                                |
|                                                                      |
|  Hayward is GONE -- inner join only keeps matching pairs.            |
|                                                                      |
+=====================================================================+
```

### Explicit Column Lists in Joins

`SELECT *` in a join concatenates all columns from both tables. You get two columns with the city name (`weather.city` and `cities.name`). Better to be explicit:

```sql
SELECT city, temp_lo, temp_hi, prcp, date, location
    FROM weather JOIN cities ON city = name;
```

When column names are ambiguous, qualify them with the table name:

```sql
SELECT weather.city, weather.temp_lo, cities.location
    FROM weather JOIN cities ON weather.city = cities.name;
```

Good habit: always qualify column names in join queries, even when not strictly required. It makes the query self-documenting.

### Old-Style Implicit Join Syntax

Before SQL-92, joins were written as comma-separated tables in `FROM` with the condition in `WHERE`:

```sql
SELECT * FROM weather, cities WHERE city = name;
```

This produces the same result but is harder to read. The explicit `JOIN ... ON` syntax separates the join condition from the filter conditions, making intent clearer. Use the modern form.

### Left Outer Join

What if you want ALL weather rows, even when there is no matching city?

```sql
SELECT *
    FROM weather LEFT OUTER JOIN cities ON weather.city = cities.name;
```

```
+=====================================================================+
|              LEFT OUTER JOIN vs INNER JOIN                            |
+=====================================================================+
|                                                                      |
|  INNER JOIN result:                                                  |
|  +---------------+-----------+                                       |
|  | city          | location  |                                       |
|  +===============+===========+                                       |
|  | San Francisco | (-194,53) |                                       |
|  | San Francisco | (-194,53) |                                       |
|  +---------------+-----------+                                       |
|  2 rows. Hayward excluded.                                           |
|                                                                      |
|  LEFT OUTER JOIN result:                                             |
|  +---------------+-----------+                                       |
|  | city          | location  |                                       |
|  +===============+===========+                                       |
|  | San Francisco | (-194,53) |                                       |
|  | San Francisco | (-194,53) |                                       |
|  | Hayward       | NULL      |  <-- Kept! Missing values are NULL.   |
|  +---------------+-----------+                                       |
|  3 rows. All weather rows preserved.                                 |
|                                                                      |
|  LEFT = "keep all rows from the LEFT table (weather)"               |
|  RIGHT OUTER JOIN = keep all from the RIGHT table                    |
|  FULL OUTER JOIN = keep all from BOTH tables                         |
|                                                                      |
+=====================================================================+
```

The left table (the one written before `LEFT OUTER JOIN`) has all its rows preserved. Where no matching right-table row exists, the right-table columns are filled with NULL.

**Question to think about:** If you switched the table order -- `FROM cities LEFT OUTER JOIN weather ON ...` -- which rows would be preserved? Would Hayward still appear?

### Self Joins

A table can be joined to itself. This is useful for comparing rows within the same table. Example: find all pairs of weather records where one day's low temperature is below another day's low, but the first day's high is above the second day's high.

```sql
SELECT w1.city, w1.temp_lo AS low, w1.temp_hi AS high,
       w2.city, w2.temp_lo AS low, w2.temp_hi AS high
    FROM weather w1 JOIN weather w2
        ON w1.temp_lo < w2.temp_lo AND w1.temp_hi > w2.temp_hi;
```

```
+=====================================================================+
|                      SELF JOIN CONCEPT                                |
+=====================================================================+
|                                                                      |
|  The same table appears TWICE with different aliases:                |
|                                                                      |
|  weather AS w1               weather AS w2                           |
|  +-----------+-----+-----+   +-----------+-----+-----+              |
|  | city      | lo  | hi  |   | city      | lo  | hi  |              |
|  +===========+=====+=====+   +===========+=====+=====+              |
|  | SF        | 46  | 50  |   | SF        | 46  | 50  |              |
|  | SF        | 43  | 57  |   | SF        | 43  | 57  |              |
|  | Hayward   | 37  | 54  |   | Hayward   | 37  | 54  |              |
|  +-----------+-----+-----+   +-----------+-----+-----+              |
|                                                                      |
|  Condition: w1.temp_lo < w2.temp_lo AND w1.temp_hi > w2.temp_hi     |
|                                                                      |
|  PostgreSQL checks every combination of (w1 row, w2 row).           |
|  For w1 = Hayward(37,54) and w2 = SF(46,50):                        |
|    37 < 46? YES.   54 > 50? YES.   --> This pair appears.           |
|                                                                      |
+=====================================================================+
```

### Table Aliases

Aliases shorten table names in queries. Essential for self joins, convenient everywhere:

```sql
SELECT w.city, w.temp_lo, c.location
    FROM weather w JOIN cities c ON w.city = c.name;
```

**Cross-stack connection:** In SQLAlchemy, joins map to `.join()`:

```
  SQL                                       SQLAlchemy
  ---                                       ----------
  FROM weather JOIN cities ON ...    -->    session.query(Weather).join(City, ...)
  LEFT OUTER JOIN                    -->    .outerjoin(City, ...)
```

**Question to think about:** When would you use a self join in a real application? Think about hierarchical data -- employees and their managers, categories and subcategories -- where parent and child rows live in the same table.

---

## Chapter 6: Aggregate Functions

Aggregates compute a single result from a set of rows.

### Basic Aggregates

```sql
SELECT max(temp_lo) FROM weather;   -- returns 46
SELECT min(temp_lo) FROM weather;
SELECT avg(temp_lo) FROM weather;
SELECT sum(temp_lo) FROM weather;
SELECT count(*) FROM weather;       -- count all rows
```

### The WHERE + Aggregate Trap

This is **wrong**:

```sql
-- ERROR: aggregate functions are not allowed in WHERE
SELECT city FROM weather WHERE temp_lo = max(temp_lo);
```

Why? Because `WHERE` is evaluated **before** aggregates are computed. The database filters rows first, then aggregates what remains. You cannot reference an aggregate result in the filter that runs before it exists.

The fix -- use a **subquery**:

```sql
SELECT city FROM weather
    WHERE temp_lo = (SELECT max(temp_lo) FROM weather);
```

The subquery runs first, returns `46`, and the outer query becomes `WHERE temp_lo = 46`.

### GROUP BY

`GROUP BY` partitions rows into groups, then applies aggregates to each group separately:

```sql
SELECT city, count(*), max(temp_lo)
    FROM weather
    GROUP BY city;
```

Result:

```
     city      | count | max
---------------+-------+-----
 Hayward       |     1 |  37
 San Francisco |     2 |  46
```

### HAVING -- Filtering Groups

`HAVING` filters groups after aggregation, the same way `WHERE` filters rows before aggregation:

```sql
SELECT city, count(*), max(temp_lo)
    FROM weather
    GROUP BY city
    HAVING max(temp_lo) < 40;
```

This returns only Hayward (whose max temp_lo is 37, which is < 40).

```
+=====================================================================+
|             WHERE vs HAVING -- EXECUTION ORDER                       |
+=====================================================================+
|                                                                      |
|  Step 1: FROM                                                        |
|  +---------------+---------+---------+------+------------+           |
|  | city          | temp_lo | temp_hi | prcp | date       |           |
|  | San Francisco |      46 |      50 | 0.25 | 1994-11-27 |           |
|  | San Francisco |      43 |      57 |  0.0 | 1994-11-29 |           |
|  | Hayward       |      37 |      54 |      | 1994-11-29 |           |
|  +---------------+---------+---------+------+------------+           |
|                  |                                                    |
|  Step 2: WHERE   |  Filters individual ROWS (no aggregates allowed)  |
|                  v                                                    |
|  (example: WHERE city LIKE 'S%' would remove Hayward here)          |
|                  |                                                    |
|  Step 3: GROUP BY|  Partitions remaining rows into groups            |
|                  v                                                    |
|  +-- San Francisco group: 2 rows  max(temp_lo) = 46                 |
|  +-- Hayward group:       1 row   max(temp_lo) = 37                 |
|                  |                                                    |
|  Step 4: HAVING  |  Filters GROUPS (aggregates allowed here)         |
|                  v                                                    |
|  (example: HAVING max(temp_lo) < 40 keeps only Hayward)             |
|                  |                                                    |
|  Step 5: SELECT  |  Computes output columns                         |
|                  v                                                    |
|  Final result                                                        |
|                                                                      |
+=====================================================================+
```

**Key efficiency principle:** Put non-aggregate conditions in `WHERE`, not `HAVING`. `WHERE` filters rows before grouping happens, which means fewer rows to group and aggregate. `HAVING` runs after all the grouping work is done.

### LIKE Pattern Matching

`LIKE` in a `WHERE` clause matches string patterns:

```sql
SELECT city, count(*), max(temp_lo)
    FROM weather
    WHERE city LIKE 'S%'
    GROUP BY city;
```

`S%` means "starts with S." The `%` is a wildcard for any sequence of characters.

### The FILTER Clause

`FILTER` lets you apply a condition to a specific aggregate without affecting others:

```sql
SELECT city,
       count(*) FILTER (WHERE temp_lo < 45) AS cold_days,
       max(temp_lo)
    FROM weather
    GROUP BY city;
```

Here, `count(*)` only counts rows where `temp_lo < 45`, but `max(temp_lo)` still sees **all** rows in each group. Without `FILTER`, you would need a `CASE` expression or a subquery to achieve this.

**Question to think about:** How would you write the `FILTER` query above without using `FILTER`? Think about `CASE WHEN ... THEN 1 ELSE NULL END` inside `count()`. Which is more readable?

**Question to think about:** If you have a `WHERE` clause AND a `HAVING` clause in the same query, which one runs first? Could you move a condition from `HAVING` to `WHERE` if it does not involve an aggregate? What would you gain by doing so?

---

## Chapter 7: Updates and Deletions

### UPDATE

Modify existing rows:

```sql
UPDATE weather
    SET temp_hi = temp_hi - 2, temp_lo = temp_lo - 2
    WHERE date > '1994-11-28';
```

This subtracts 2 from both temperature columns for all rows after November 28. You can update multiple columns in a single statement. The `WHERE` clause selects which rows are affected -- without it, ALL rows are updated.

### DELETE

Remove rows:

```sql
DELETE FROM weather WHERE city = 'Hayward';
```

**WARNING:** This deletes ALL rows with no confirmation:

```sql
DELETE FROM weather;
```

There is no "are you sure?" prompt. The rows are gone. Always double-check your `WHERE` clause before running `DELETE`. A common safety practice: run a `SELECT` with the same `WHERE` clause first to see which rows would be affected.

**Cross-stack connection:**

```
  SQL                                    SQLAlchemy
  ---                                    ----------
  UPDATE weather SET ... WHERE ...  -->  session.query(Weather).filter(...).update({...})
  DELETE FROM weather WHERE ...     -->  session.query(Weather).filter(...).delete()
```

**Question to think about:** What happens if you run `UPDATE weather SET temp_hi = temp_hi - 2` without a `WHERE` clause? How is this different from the danger of `DELETE FROM weather` without `WHERE`? One is recoverable in principle, the other is not -- why?

**Question to think about:** You just learned that `DELETE FROM weather;` removes all rows. Does it also remove the table itself? What is the difference between `DELETE FROM weather;` and `DROP TABLE weather;`?

---

## Chapter 8: Exercises

Use the `weather` and `cities` tables from this lesson. Create and populate them first:

```sql
CREATE TABLE weather (
    city        varchar(80),
    temp_lo     int,
    temp_hi     int,
    prcp        real,
    date        date
);

CREATE TABLE cities (
    name        varchar(80),
    location    point
);

INSERT INTO weather VALUES ('San Francisco', 46, 50, 0.25, '1994-11-27');
INSERT INTO weather VALUES ('San Francisco', 43, 57, 0.0, '1994-11-29');
INSERT INTO weather VALUES ('Hayward', 37, 54, NULL, '1994-11-29');

INSERT INTO cities VALUES ('San Francisco', '(-194.0, 53.0)');
```

### Exercise 1: Basic SELECT (Warm-up)

Write a query that returns only the `city` and `date` columns from the weather table, ordered by date.

### Exercise 2: Computed Columns

Write a query that shows each city, date, and the **temperature range** (difference between high and low) as a column named `temp_range`. Order by the temperature range descending.

### Exercise 3: Filtering

Write a query that returns all weather rows where precipitation is either NULL or greater than zero. (Hint: you need `IS NULL` for the NULL check -- `= NULL` does not work in SQL.)

### Exercise 4: Inner Join

Write a query that returns the city name, date, temperature high, and location for all weather entries that have a matching city in the `cities` table. Use explicit `JOIN ... ON` syntax and qualify all column names.

### Exercise 5: Left Outer Join

Modify your Exercise 4 query to include weather entries even when there is no matching city. Verify that Hayward appears with NULL for the location.

### Exercise 6: Aggregates With GROUP BY

Write a query that returns each city, its number of weather records, the average low temperature (rounded to 1 decimal), and the total precipitation. Use `GROUP BY`.

### Exercise 7: HAVING Filter

Modify Exercise 6 to only show cities where the average low temperature is above 40.

### Exercise 8: Self Join

Write a self-join query that finds all pairs of weather records where the two records are from different cities but on the same date. Return both city names and the date.

### Exercise 9: Subquery

Without using `GROUP BY`, write a query that returns the city (or cities) with the highest single-day low temperature. Use a subquery with `max()`.

### Exercise 10: FILTER Clause (Challenge)

Write a single query grouped by city that shows:
- Total number of weather records
- Number of records where `temp_hi` was above 55
- The maximum precipitation, but only for days where the low was below 45

Use the `FILTER` clause for the conditional aggregates.

---

## Quick Reference: SQL Commands Covered

| Command | Purpose | Example |
|---------|---------|---------|
| `CREATE TABLE` | Define a new table | `CREATE TABLE t (col type, ...);` |
| `DROP TABLE` | Remove a table entirely | `DROP TABLE t;` |
| `INSERT INTO` | Add rows | `INSERT INTO t (col) VALUES (val);` |
| `COPY` | Bulk load from file | `COPY t FROM '/path/file.txt';` |
| `SELECT ... FROM` | Query rows | `SELECT col FROM t;` |
| `WHERE` | Filter rows | `WHERE col = 'value'` |
| `ORDER BY` | Sort results | `ORDER BY col ASC` |
| `DISTINCT` | Remove duplicate rows | `SELECT DISTINCT col FROM t;` |
| `JOIN ... ON` | Combine tables (inner) | `FROM a JOIN b ON a.x = b.y` |
| `LEFT OUTER JOIN` | Keep all left-table rows | `FROM a LEFT OUTER JOIN b ON ...` |
| `GROUP BY` | Partition rows for aggregation | `GROUP BY col` |
| `HAVING` | Filter groups after aggregation | `HAVING count(*) > 1` |
| `FILTER` | Per-aggregate row condition | `count(*) FILTER (WHERE ...)` |
| `AS` | Alias a column or table | `SELECT col AS alias` |
| `LIKE` | Pattern matching | `WHERE col LIKE 'S%'` |
| `UPDATE` | Modify existing rows | `UPDATE t SET col = val WHERE ...;` |
| `DELETE FROM` | Remove rows | `DELETE FROM t WHERE ...;` |

### Aggregate Functions

| Function | Returns |
|----------|---------|
| `count(*)` | Number of rows |
| `sum(col)` | Total of all values |
| `avg(col)` | Arithmetic mean |
| `max(col)` | Largest value |
| `min(col)` | Smallest value |

---

## Questions

1. What happens after you run `DELETE FROM weather;` and then try to insert a new row?

   A) The INSERT fails because `DELETE FROM` also removes the table structure
   B) The INSERT succeeds because `DELETE FROM` only removes rows -- the table structure remains intact
   C) The INSERT succeeds but the row is immediately deleted by a cascading rule
   D) PostgreSQL prompts for confirmation before allowing the INSERT

2. You want every city with its location, including cities that have weather records but no entry in the `cities` table. Which approach is correct?

   A) `INNER JOIN` with `weather` on the left -- inner joins preserve all rows from both tables
   B) `LEFT OUTER JOIN` with `cities` on the left -- this preserves all cities entries
   C) `LEFT OUTER JOIN` with `weather` on the left -- this preserves all weather rows, filling in NULL for missing city locations
   D) `CROSS JOIN` -- this automatically handles missing matches by inserting NULLs

3. Why does the query `SELECT city FROM weather WHERE temp_lo = max(temp_lo);` produce an error?

   A) `max()` is not a valid PostgreSQL function -- you must use `GREATEST()` instead
   B) `WHERE` is evaluated before aggregate functions are computed, so `max(temp_lo)` does not exist yet at the filtering stage
   C) You cannot compare an integer column to the result of an aggregate function under any circumstances
   D) The query is missing a `GROUP BY` clause, which is always required when using `max()`

4. You have a query with both `WHERE` and `HAVING`. A filter condition does NOT involve an aggregate function. Where should you place it for best performance?

   A) In `HAVING` -- it runs after grouping, which gives more accurate results
   B) In `WHERE` -- it filters rows before grouping, reducing the number of rows that need to be grouped and aggregated
   C) In either clause -- PostgreSQL optimizes them identically regardless of placement
   D) In a separate subquery -- non-aggregate conditions cannot appear in `WHERE` or `HAVING`

5. What is the main risk of using `INSERT INTO weather VALUES (...)` without listing column names explicitly?

   A) PostgreSQL will reject the statement because column names are always required
   B) The insert depends on the column order from `CREATE TABLE` -- schema changes like reordering or adding columns can silently insert data into wrong columns
   C) Without column names, PostgreSQL inserts NULL for every column
   D) The values are inserted in reverse order of the column definitions

6. What does `SELECT DISTINCT city FROM weather;` guarantee about the result?

   A) Each city appears exactly once AND the results are sorted alphabetically
   B) Each city appears exactly once, but row order is NOT guaranteed -- you must add `ORDER BY` for sorted results
   C) Duplicate rows are removed only if they are adjacent in storage
   D) It returns only cities that appear more than once in the table

7. If the `weather` table has 1,000 rows, how many row combinations must PostgreSQL evaluate in a self-join before applying the `ON` filter?

   A) 1,000 -- one comparison per row
   B) 2,000 -- each row is compared with itself and one other
   C) 1,000,000 -- the Cartesian product grows quadratically (1,000 x 1,000)
   D) 500,000 -- PostgreSQL automatically skips half the combinations for symmetry

8. Which of the following correctly uses the `FILTER` clause to count rainy days per city?

   A) `SELECT city, count(*) FILTER (WHERE prcp > 0.0) AS rainy_days FROM weather GROUP BY city;`
   B) `SELECT city, count(FILTER prcp > 0.0) AS rainy_days FROM weather GROUP BY city;`
   C) `SELECT city, FILTER(count(*), prcp > 0.0) AS rainy_days FROM weather GROUP BY city;`
   D) `SELECT city, count(*) WHERE FILTER (prcp > 0.0) AS rainy_days FROM weather GROUP BY city;`

## Answers Hidden

1. **B** — `DELETE FROM` only removes rows; the table structure (columns, types, constraints) remains intact. The INSERT would succeed immediately. By contrast, `DROP TABLE` removes the table entirely and the INSERT would fail with "relation does not exist."

2. **C** — A `LEFT OUTER JOIN` with `weather` on the left preserves all weather rows. Cities like Hayward that have no entry in the `cities` table will appear with NULL for the location column. An inner join would exclude them entirely.

3. **B** — `WHERE` is evaluated before aggregate functions are computed in PostgreSQL's execution pipeline. The `max(temp_lo)` value does not exist yet at the filtering stage. The fix is a subquery: `WHERE temp_lo = (SELECT max(temp_lo) FROM weather)`.

4. **B** — `WHERE` filters individual rows before grouping, so fewer rows need to be grouped and aggregated. Putting a non-aggregate condition in `HAVING` wastes work by grouping rows that could have been eliminated earlier.

5. **B** — Without explicit column names, the insert depends on the exact column order from `CREATE TABLE`. Schema changes like adding or reordering columns can silently insert data into the wrong columns. The explicit form `INSERT INTO weather (city, temp_lo, ...) VALUES (...)` is self-documenting and survives schema changes.

6. **B** — `DISTINCT` guarantees each city appears exactly once, but does NOT guarantee any particular order. PostgreSQL returns rows in whatever order is most convenient. Add `ORDER BY city` for alphabetical results.

7. **C** — The database evaluates the Cartesian product: 1,000 x 1,000 = 1,000,000 combinations before applying the `ON` filter. This grows quadratically, making self-joins on large tables expensive without proper indexing.

8. **A** — The correct `FILTER` syntax places the clause after the aggregate function: `count(*) FILTER (WHERE prcp > 0.0)`. The `FILTER` clause restricts which rows that specific aggregate sees, without affecting other aggregates in the same query.

---

## Summary Checklist

Before moving on, make sure you can answer YES to all of these:

- [ ] I can create a table with appropriate column types
- [ ] I list columns explicitly in INSERT statements (not relying on implicit order)
- [ ] I use single quotes for string/date values, never double quotes
- [ ] I always use ORDER BY when row order matters
- [ ] I understand that `SELECT *` is fine for exploration but not production code
- [ ] I use explicit `JOIN ... ON` syntax, not comma-separated tables in FROM
- [ ] I can explain the difference between INNER JOIN and LEFT OUTER JOIN
- [ ] I know that WHERE runs before GROUP BY, and HAVING runs after
- [ ] I never put aggregate functions in a WHERE clause
- [ ] I put non-aggregate conditions in WHERE (not HAVING) for efficiency
- [ ] I understand that `DELETE FROM t;` removes all rows but keeps the table
- [ ] I run a SELECT with the same WHERE clause before running UPDATE or DELETE
- [ ] I know the difference between `DROP TABLE` (removes table) and `DELETE FROM` (removes rows)

---

*Next lesson: Chapter 3 -- Advanced Features: views, foreign keys, transactions, window functions, and inheritance.*
