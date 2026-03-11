# LESSON 02: <span style="color: #FF8C00;">The Simple-Postgres Bookstore — A Complete Codebase Walkthrough</span>

## Prerequisites

- Lesson 01: PostgreSQL Getting Started (assigned)
- Basic Python knowledge (functions, imports, context managers)
- Understanding of what a relational database is (tables store rows of structured data)

---

## Learning Objectives

By the end of this lesson, you will understand:

1. How a Python + PostgreSQL application is structured and why each file exists
2. How relational database schema design works: tables, relationships, constraints, and indexes
3. How Python connects to PostgreSQL using psycopg2 and environment variables
4. How database seeding works with transactions, parameterized queries, and RETURNING
5. Five essential SQL query patterns: JOINs, aggregations, filtering, LEFT JOIN, and LIMIT
6. The correct execution order and why it matters

---

## PART 1: <span style="color: #FF8C00;">Architecture — How the Files Depend on Each Other</span>

Before looking at any code, you need to understand the **dependency graph** — which file uses which, and in what order things must run.

```
                     .env
                      |
                      v
    schema.sql       db.py  <--- central hub, everything depends on this
                      |
              +-------+-------+
              |               |
              v               v
           seed.py        queries.py
```

Here is what each file does and WHY it exists:

| File | Role | Analogy |
|------|------|---------|
| `.env` | Stores database credentials | The keychain to your house |
| `db.py` | Creates database connections | The front door — every visitor uses it |
| `schema.sql` | Defines the table structure | The blueprint of the house |
| `seed.py` | Inserts sample data | Furnishing the house |
| `queries.py` | Reads data back out | Living in the house |

### <span style="color: #FFA500;">The Execution Order (This Is Critical)</span>

You MUST run things in this order:

```
Step 1:  psql -f schema.sql bookstore     (build the tables)
Step 2:  python seed.py                    (fill them with data)
Step 3:  python queries.py                 (query the data)
```

WHY this order? Because of **dependencies**:

- You cannot insert data into tables that do not exist (seed.py needs schema.sql first)
- You cannot query data that has not been inserted (queries.py needs seed.py first)
- Both seed.py and queries.py need db.py, which needs .env

This is a pattern you will see in every database application: **schema first, data second, queries third**.

---

## PART 2: <span style="color: #FF8C00;">The Connection Layer — db.py</span>

This is the foundation. Every other Python file imports `get_connection()` from here.

### <span style="color: #FFA500;">What psycopg2 Is</span>

psycopg2 is the most widely-used PostgreSQL adapter for Python. It translates between Python and the PostgreSQL wire protocol. When you call `psycopg2.connect(...)`, it opens a TCP connection to the PostgreSQL server (usually on port 5432) and authenticates using the credentials you provide.

Think of it like a phone call: psycopg2 dials the PostgreSQL server, says "I am user `alan` and my password is `changeme`, I want to talk to the `bookstore` database," and if everything checks out, PostgreSQL picks up.

### <span style="color: #FFA500;">Why Environment Variables?</span>

Look at how credentials are loaded:

```python
from dotenv import load_dotenv

_ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(_ENV_PATH)
```

The `.env` file contains:
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bookstore
DB_USER=alan
DB_PASSWORD=changeme
```

`load_dotenv()` reads this file and sets these as environment variables in the running process. Then `os.getenv("DB_HOST")` retrieves them.

**WHY not just hardcode the credentials?** Three reasons:

1. **Security**: Hardcoded passwords end up in version control. Anyone who can read your Git history can read your password. Environment variables stay on the machine.
2. **Flexibility**: Development uses `localhost`, staging uses `staging-db.internal`, production uses `prod-db.internal`. Same code, different `.env` files.
3. **Convention**: The "12-Factor App" methodology (widely followed in industry) says configuration should come from the environment, never from code.

### <span style="color: #FFA500;">What RealDictCursor Does</span>

```python
cursor_factory=RealDictCursor
```

By default, psycopg2 returns rows as tuples:

```python
row = (1, "Dune", "9780441172719", 17.99)
print(row[0])   # 1 — but what IS column 0? You have to remember.
```

With RealDictCursor, rows come back as dictionaries:

```python
row = {"id": 1, "title": "Dune", "isbn": "9780441172719", "price": Decimal("17.99")}
print(row["title"])   # "Dune" — self-documenting
```

The trade-off: dictionaries use more memory than tuples. For a bookstore with thousands of rows, this is irrelevant. For a data pipeline processing millions of rows, you would switch back to tuples or use server-side cursors.

### <span style="color: #FFA500;">The Error Handling Pattern</span>

```python
missing = [v for v in required_vars if not os.getenv(v)]
if missing:
    print(f"ERROR: Missing environment variables: {', '.join(missing)}")
    sys.exit(1)
```

This is **fail-fast** design. Instead of letting the code crash deep inside `psycopg2.connect()` with a confusing error, it checks preconditions first and gives a clear, actionable error message. This is a professional habit. In production, vague errors cost hours of debugging time. Clear errors save those hours.

The `try/except psycopg2.OperationalError` below it catches connection failures (wrong host, database not running, bad password) and converts them to a readable message.

### <span style="color: #FFA500;">What "Caller is responsible for closing" Means</span>

`get_connection()` returns an open connection. It does NOT close it. This is a deliberate design choice: the calling code decides when to close, because only the calling code knows when it is done. You will see this pattern in every file that uses it:

```python
conn = get_connection()
try:
    # ... use the connection ...
finally:
    conn.close()
```

The `finally` block guarantees the connection closes even if an exception occurs. Leaking connections (forgetting to close them) is one of the most common bugs in database applications. PostgreSQL has a limited number of connection slots (default: 100). Leak enough connections and your application stops being able to connect at all.

---

## PART 3: <span style="color: #FF8C00;">Schema Design — schema.sql</span>

This is where the real database thinking happens. The schema defines five tables and their relationships.

### <span style="color: #FFA500;">The Entity-Relationship Model</span>

```
  authors              books                order_items           orders            customers
 +--------+        +----------+           +------------+       +--------+        +-----------+
 | id  PK |---+    | id    PK |------+    | id      PK |    +--| id  PK |    +---| id     PK |
 | name   |   +----| author_id FK|   +----| book_id FK |    |  | cust_id FK--+   | name      |
 | bio    |        | title    |        | order_id FK-+   |  | order_date|       | email  UQ |
 | created|        | isbn  UQ |        | quantity   |   +--| total     |       | created   |
 +--------+        | price    |        | price      |      | created   |       +-----------+
                   | pub_date |        +------------+      +--------+
                   | created  |
                   +----------+

 1 author  -->  many books       (one-to-many)
 1 order   -->  many order_items (one-to-many)
 1 customer --> many orders      (one-to-many)
 1 book    -->  many order_items (one-to-many, a book can appear in multiple orders)
```

There are four relationships here, and they are ALL **one-to-many**. This is the most common relationship type in relational databases. The "many" side holds a **foreign key** pointing back to the "one" side.

### <span style="color: #FFA500;">The order_items Table: A Junction Pattern</span>

This is the most subtle part of the schema. An order can contain multiple books, and a book can appear in multiple orders. That is a **many-to-many** relationship between books and orders.

You CANNOT represent many-to-many directly in a relational database. You resolve it with a **junction table** (also called a join table, bridge table, or associative entity). That is what `order_items` is:

```
orders  <---one-to-many--->  order_items  <---many-to-one--->  books
```

Each row in `order_items` says: "In order #X, book #Y was purchased with quantity Z at price P."

### <span style="color: #FFA500;">Constraints — The Database as Guardian</span>

Constraints are rules the database enforces automatically. They prevent bad data from ever entering the system. Look at what this schema enforces:

**PRIMARY KEY** (`id SERIAL PRIMARY KEY`):
- Every table has an auto-incrementing integer `id`
- SERIAL means PostgreSQL generates the next value automatically
- PRIMARY KEY means: must be unique, cannot be NULL, automatically indexed

**NOT NULL** (`name TEXT NOT NULL`):
- The column must have a value. You cannot insert an author without a name.
- WHY: Null names break display logic, search, sorting, and reporting. Enforce it at the database level so no bug in your Python code can create a nameless author.

**UNIQUE** (`isbn VARCHAR(13) NOT NULL UNIQUE`):
- No two books can have the same ISBN. The database rejects duplicates.
- WHY: ISBNs are real-world identifiers. If two books share an ISBN, your ordering system breaks.

**CHECK** (`price NUMERIC(10,2) NOT NULL CHECK (price >= 0)`):
- The price must be zero or positive. The database rejects negative prices.
- WHY: A negative price would mean you pay the customer. CHECK constraints catch data errors that no amount of Python validation can guarantee (what about data loaded via SQL scripts, migrations, or admin tools?).

**FOREIGN KEY** (`author_id INT NOT NULL REFERENCES authors(id) ON DELETE RESTRICT`):
- author_id must match an existing row in the authors table.
- ON DELETE RESTRICT means: if you try to delete an author who has books, PostgreSQL refuses. It will NOT orphan the books.
- WHY: Without foreign keys, you can delete an author and leave behind books pointing to a nonexistent author_id. This is called a **referential integrity violation** and it corrupts your data.

**ON DELETE CASCADE vs ON DELETE RESTRICT** — a critical distinction:

```
order_items:  REFERENCES orders(id)   ON DELETE CASCADE
              REFERENCES books(id)    ON DELETE RESTRICT
```

- CASCADE: Deleting an order automatically deletes its order_items. This makes sense — an order without items is meaningless.
- RESTRICT: Deleting a book that appears in an order is BLOCKED. This makes sense — you need the book record for historical order data.

This is not arbitrary. Think about the business meaning: "Can I destroy order #47's line items if I destroy order #47?" Yes — they are part of that order. "Can I delete 'Dune' from the books table if someone has bought it?" No — that would erase purchase history.

### <span style="color: #FFA500;">Indexes — Making Queries Fast</span>

```sql
CREATE INDEX IF NOT EXISTS idx_books_author_id ON books(author_id);
CREATE INDEX IF NOT EXISTS idx_books_isbn      ON books(isbn);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_date  ON orders(order_date);
```

An index is a separate data structure (usually a B-tree) that lets PostgreSQL find rows without scanning the entire table.

Without an index on `books.author_id`, the query `SELECT * FROM books WHERE author_id = 3` must read EVERY row in the books table and check each one. This is called a **sequential scan**. With 10 books, this is instant. With 10 million books, it takes seconds.

With an index, PostgreSQL looks up `author_id = 3` in the B-tree (logarithmic time), gets the row locations, and fetches only those rows. This is called an **index scan**.

**Which columns get indexes?**

The schema indexes:
- Foreign key columns (author_id, customer_id, order_id, book_id) — because JOINs use them
- Columns used in WHERE clauses (isbn, email, order_date) — because filtering uses them

Note that PRIMARY KEY and UNIQUE columns are automatically indexed by PostgreSQL. That is why there is no explicit index on `authors.id` or `books.isbn` (UNIQUE already created one).

### <span style="color: #FFA500;">The Transaction Wrapper (BEGIN / COMMIT)</span>

```sql
BEGIN;
-- all the CREATE TABLE statements
COMMIT;
```

This wraps the entire schema creation in a single transaction. If any statement fails (say, a typo in one CREATE TABLE), ALL changes roll back. You do not end up with a half-created schema. This is **atomicity** — one of the four ACID properties of transactions.

### <span style="color: #FFA500;">Data Types — Choosing Correctly</span>

| Column | Type | Why This Type |
|--------|------|---------------|
| id | SERIAL | Auto-incrementing integer, perfect for surrogate keys |
| name | TEXT | Variable-length, no artificial limit. PostgreSQL TEXT is as fast as VARCHAR. |
| isbn | VARCHAR(13) | ISBNs are exactly 10 or 13 chars. VARCHAR enforces a max length. |
| price | NUMERIC(10,2) | Exact decimal arithmetic. NEVER use FLOAT for money — `0.1 + 0.2 != 0.3` in floating point. |
| published_date | DATE | Calendar date without time component. |
| created_at | TIMESTAMPTZ | Timestamp WITH time zone. Always use TIMESTAMPTZ, not TIMESTAMP, to avoid timezone bugs. |
| quantity | INT | Whole number. CHECK (quantity > 0) prevents zero-quantity items. |

---

## PART 4: <span style="color: #FF8C00;">Seeding — seed.py</span>

Seeding is inserting sample data for development and testing. This file shows several important database patterns.

### <span style="color: #FFA500;">The Transaction Pattern</span>

```python
conn = get_connection()
try:
    with conn.cursor() as cur:
        # ... all inserts happen here ...
    conn.commit()
except Exception as exc:
    conn.rollback()
    raise
finally:
    conn.close()
```

This is the canonical database transaction pattern in Python. Here is what each part does:

1. **Get a connection** — opens a TCP connection to PostgreSQL
2. **Open a cursor** — the `with` statement creates a cursor and closes it when done. A cursor is how you send SQL to the database.
3. **Do all work** — every INSERT runs through this one cursor, in this one transaction
4. **commit()** — makes all changes permanent. Until you commit, nothing is visible to other connections.
5. **rollback()** — if anything fails, undo ALL changes. If Alice's order is inserted but Carol's fails, rollback removes Alice's too. This maintains data consistency.
6. **close()** — always close the connection, success or failure

WHY is this important? Imagine the seed inserts 3 authors and then crashes on the 4th. Without rollback, you have 3 orphaned authors in the database. The next time you run the seed, it might try to insert them again and fail on the UNIQUE constraint. Rollback keeps your database clean.

### <span style="color: #FFA500;">Parameterized Queries — The Security Foundation</span>

```python
cur.execute(
    "INSERT INTO orders (customer_id, total) VALUES (%s, %s) RETURNING id",
    (customer_ids[0], total_1),
)
```

The `%s` placeholders are NOT Python string formatting. They are **parameter markers** that psycopg2 processes. psycopg2 sends the SQL template and the values separately to PostgreSQL, which treats the values as DATA, never as SQL code.

**WHY this matters** — SQL injection:

```python
# DANGEROUS — never do this
cur.execute(f"SELECT * FROM books WHERE title = '{user_input}'")

# If user_input is:   ' OR 1=1; DROP TABLE books; --
# The SQL becomes:    SELECT * FROM books WHERE title = '' OR 1=1; DROP TABLE books; --'
# Your books table is now gone.

# SAFE — always do this
cur.execute("SELECT * FROM books WHERE title = %s", (user_input,))
# psycopg2 escapes the value. The SQL only ever sees it as a string parameter.
```

This is not optional. Parameterized queries are the single most important security practice in database programming. Every query in this codebase uses them correctly.

### <span style="color: #FFA500;">RETURNING — Getting Auto-Generated IDs</span>

```python
cur.execute(
    """
    INSERT INTO authors (name, bio) VALUES
        (%s, %s), (%s, %s), (%s, %s), (%s, %s), (%s, %s)
    RETURNING id
    """,
    ( ... ),
)
author_ids = [row["id"] for row in cur.fetchall()]
```

RETURNING is a PostgreSQL feature (not standard SQL) that makes INSERT return data, like a SELECT. Here, after inserting 5 authors, PostgreSQL returns the 5 auto-generated `id` values.

WHY is this needed? Because the seed needs those IDs to create books. Each book has an `author_id` foreign key. Without RETURNING, you would need a separate SELECT query:

```python
# Without RETURNING (two round trips to the database):
cur.execute("INSERT INTO authors (name, bio) VALUES (%s, %s)", ("Le Guin", "..."))
cur.execute("SELECT id FROM authors WHERE name = %s", ("Le Guin",))
author_id = cur.fetchone()["id"]

# With RETURNING (one round trip):
cur.execute("INSERT INTO authors (name, bio) VALUES (%s, %s) RETURNING id", ("Le Guin", "..."))
author_id = cur.fetchone()["id"]
```

RETURNING saves a database round trip and avoids a race condition (what if another process inserts a different Le Guin between your INSERT and SELECT?).

### <span style="color: #FFA500;">The Data Chain: IDs Flow Downward</span>

Watch how IDs cascade through the seed:

```
1. Insert authors       --> capture author_ids
2. Insert books         --> uses author_ids, then fetches book_ids
3. Insert customers     --> capture customer_ids
4. Insert orders        --> uses customer_ids, captures order_ids
5. Insert order_items   --> uses order_ids + book_ids
```

This mirrors the foreign key relationships in the schema. You MUST insert parents before children because the foreign key constraint checks that the parent row exists at INSERT time.

---

## PART 5: <span style="color: #FF8C00;">Query Patterns — queries.py</span>

This file demonstrates five fundamental SQL query patterns. Every database application uses some combination of these.

### <span style="color: #FFA500;">Pattern 1: JOIN with Filtering (books_by_author)</span>

```sql
SELECT b.title, b.isbn, b.price, b.published_date, a.name AS author
FROM books b
JOIN authors a ON a.id = b.author_id
WHERE a.name ILIKE %s
ORDER BY b.published_date
```

What this does, step by step:

1. **FROM books b** — start with the books table, alias it as `b`
2. **JOIN authors a ON a.id = b.author_id** — for each book, find the matching author row where the author's id equals the book's author_id
3. **WHERE a.name ILIKE %s** — filter to only authors whose name matches the pattern. ILIKE is case-insensitive LIKE (PostgreSQL extension). The `%` wildcards in `f"%{author_name}%"` make it a partial match.
4. **ORDER BY b.published_date** — sort results chronologically

The JOIN is what connects the two tables. Without it, you would have book data and author data in separate, unrelated result sets.

Think of a JOIN as looking up a reference. The book says "my author_id is 3." The JOIN says "go to the authors table, find row with id=3, and bring back the name."

### <span style="color: #FFA500;">Pattern 2: Multi-Table JOIN (order_history)</span>

```sql
SELECT
    o.id AS order_id, o.order_date, o.total AS order_total,
    b.title AS book_title, oi.quantity, oi.price AS unit_price,
    (oi.quantity * oi.price) AS line_total
FROM orders o
JOIN customers c   ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
JOIN books b       ON b.id = oi.book_id
WHERE c.email = %s
ORDER BY o.order_date DESC, oi.id
```

This chains FOUR tables together:

```
customers ---> orders ---> order_items ---> books
    c             o             oi             b

"Find the customer by email,
 get their orders,
 get each order's items,
 get each item's book title."
```

This is the power of relational databases: data is normalized (stored once, in the right table) and JOINs reassemble it on demand. The customer name is stored once in `customers`, not copied into every order.

The computed column `(oi.quantity * oi.price) AS line_total` shows that SQL can do arithmetic inline. No need to compute this in Python.

### <span style="color: #FFA500;">Pattern 3: Aggregation with GROUP BY (revenue_by_author)</span>

```sql
SELECT
    a.name AS author,
    COUNT(DISTINCT oi.id) AS items_sold,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.price) AS total_revenue
FROM authors a
JOIN books b        ON b.author_id = a.id
JOIN order_items oi ON oi.book_id  = b.id
GROUP BY a.id, a.name
ORDER BY total_revenue DESC
```

GROUP BY collapses multiple rows into one row per group. Here, all order_items for a given author are collapsed into a single summary row.

- **COUNT(DISTINCT oi.id)** — how many individual line items (not quantity, just distinct order_item rows)
- **SUM(oi.quantity)** — total units across all those line items
- **SUM(oi.quantity * oi.price)** — total revenue (units times price per unit)

WHY `GROUP BY a.id, a.name`? Because the SQL standard says: every column in SELECT that is not inside an aggregate function (SUM, COUNT, etc.) must appear in GROUP BY. The `a.id` is included because two authors could theoretically have the same name.

### <span style="color: #FFA500;">Pattern 4: Aggregation with LIMIT (top_selling_books)</span>

```sql
SELECT
    b.title, a.name AS author,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.price) AS total_revenue
FROM books b
JOIN authors a      ON a.id = b.author_id
JOIN order_items oi ON oi.book_id = b.id
GROUP BY b.id, b.title, a.name
ORDER BY units_sold DESC, total_revenue DESC
LIMIT %s
```

Same aggregation pattern as above, but with `LIMIT %s` to cap the result set. Notice that LIMIT is parameterized — the `%s` placeholder ensures the value is treated as an integer, not injectable SQL.

The ORDER BY has two columns: primary sort by units_sold, tiebreaker by total_revenue. This ensures deterministic ordering even when two books have the same unit count.

### <span style="color: #FFA500;">Pattern 5: LEFT JOIN for Finding Missing Data (customers_with_no_orders)</span>

```sql
SELECT c.id, c.name, c.email
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE o.id IS NULL
ORDER BY c.name
```

This is one of the most useful patterns in SQL. A regular JOIN (INNER JOIN) only returns rows that have matches in BOTH tables. A LEFT JOIN returns ALL rows from the left table (customers), even if there is no matching row in the right table (orders). When there is no match, the right table's columns are NULL.

```
Regular JOIN:                LEFT JOIN:
Customer | Order             Customer | Order
---------|------             ---------|------
Alice    | #1                Alice    | #1
Bob      | #2                Bob      | #2
                             Carol    | NULL   <-- no order, still appears
```

Then `WHERE o.id IS NULL` filters to ONLY the unmatched rows — customers with no orders.

This pattern answers the question: "Who is NOT in the other table?" You will use it constantly: users who never logged in, products never purchased, servers that did not report health checks.

### <span style="color: #FFA500;">The Connection-Per-Function Pattern</span>

Every query function follows the same structure:

```python
def some_query(param):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("...", (param,))
            return cur.fetchall()
    finally:
        conn.close()
```

Each function opens its own connection and closes it when done. This is simple and correct, but not optimal for high-traffic applications. In production, you would use a **connection pool** (like psycopg2.pool or SQLAlchemy's pool) that reuses connections instead of creating new ones for each query.

For a learning project, one-connection-per-function is the right choice: it is easy to understand and impossible to leak connections.

---

## PART 6: <span style="color: #FF8C00;">The Complete Data Flow</span>

Let us trace what happens from start to finish when you run this application:

```
Step 1: psql -f schema.sql bookstore
-----------------------------------------------------------------
PostgreSQL reads schema.sql, starts a transaction (BEGIN),
creates 5 tables with all constraints and indexes,
and commits (COMMIT). The database now has structure but no data.

Step 2: python seed.py
-----------------------------------------------------------------
Python starts --> imports db.py --> loads .env
            --> calls get_connection() --> TCP connection to PostgreSQL
            --> opens cursor
            --> INSERT authors (5 rows) --> RETURNING captures IDs [1,2,3,4,5]
            --> INSERT books (10 rows) using author IDs
            --> SELECT books to get book IDs
            --> INSERT customers (3 rows) --> RETURNING captures IDs
            --> INSERT orders + order_items using customer IDs and book IDs
            --> conn.commit() --> all data persisted
            --> conn.close() --> TCP connection released

Step 3: python queries.py
-----------------------------------------------------------------
main() calls each query function:
            --> books_by_author("Le Guin")
                  open connection --> execute JOIN --> return dicts --> close
            --> order_history("alice@example.com")
                  open connection --> execute 4-table JOIN --> return --> close
            --> revenue_by_author()
                  open connection --> execute aggregation --> return --> close
            --> top_selling_books()
                  open connection --> execute aggregation + LIMIT --> return --> close
            --> customers_with_no_orders()
                  open connection --> execute LEFT JOIN --> return --> close
            --> print formatted results
```

---

## Security Corner

### <span style="color: #FF8C00;">What This Codebase Gets Right</span>

1. **Parameterized queries everywhere** — no SQL injection risk
2. **Credentials in .env, not in code** — secrets stay out of version control
3. **Database-level constraints** — even if Python code has bugs, the database rejects bad data
4. **Fail-fast error handling** — clear messages instead of cryptic crashes

### <span style="color: #FF8C00;">What Could Be Improved</span>

1. **The .env file should be in .gitignore.** If this project is committed to Git, the password is exposed. Always add `.env` to `.gitignore` and provide a `.env.example` with placeholder values instead.

2. **The password "changeme" is weak.** In production, use a generated password and consider certificate-based authentication instead of passwords.

3. **No input validation in Python.** The query functions trust their callers. In a web application, you would validate inputs before they reach the database (even though parameterized queries prevent injection, you still want to reject nonsensical input early).

4. **No connection encryption.** The psycopg2.connect() call does not specify `sslmode`. In production, you should use `sslmode='require'` or `sslmode='verify-full'` to encrypt the connection between Python and PostgreSQL.

---

## Architecture Notes

### <span style="color: #FFA500;">Why This Structure Scales</span>

- **Separation of concerns**: schema, data, queries, and connection logic are each in their own file. You can change the schema without touching queries.py. You can swap PostgreSQL for another database by changing only db.py.
- **The centralized connection function**: Every file goes through `get_connection()`. If you need to add connection pooling, SSL, or logging, you change ONE place.
- **Constraints at the database level**: Even if you add a web API, mobile app, or admin script that talks to this database, the constraints protect data integrity. Defense in depth.

### <span style="color: #FFA500;">What a Production Version Would Add</span>

- **Connection pooling** — reuse connections instead of opening/closing for each query
- **Migrations** — tools like Alembic to evolve the schema over time without losing data
- **An ORM layer** — SQLAlchemy to map Python classes to tables (you will learn this later)
- **Logging** — record queries and errors for debugging
- **Retry logic** — handle transient network failures gracefully

---

## Review Questions

**Q1 (Practical):** The `order_items` table has `price` as a separate column even though `books` already has a `price` column. Why store the price twice? What would go wrong if `order_items` just referenced the book's price?

<details>
<summary>Answer</summary>
Book prices change over time. If order_items referenced the current book price, then when you raise the price of Dune from $17.99 to $19.99, all historical orders would retroactively show the new price. The order_items.price column captures the price AT THE TIME OF PURCHASE. This is called "snapshotting" or "denormalization for historical accuracy."
</details>

**Q2 (Practical):** What happens if you run `seed.py` twice without clearing the database? Which tables will cause errors and why?

<details>
<summary>Answer</summary>
The second run will fail on UNIQUE constraint violations. Specifically, the `books` table has `isbn` as UNIQUE, and `customers` has `email` as UNIQUE. Attempting to insert duplicate ISBNs or emails will raise an IntegrityError. The authors table has no UNIQUE constraint on name, so duplicate authors would be inserted (a design consideration — you might want to add a UNIQUE constraint on author name, or more likely, handle this with an UPSERT pattern: INSERT ... ON CONFLICT DO NOTHING).
</details>

**Q3 (Security):** The `.env` file contains `DB_PASSWORD=changeme`. Name three things that should be done differently in a production deployment.

<details>
<summary>Answer</summary>
1. Use a strong, randomly generated password (not "changeme")
2. Add .env to .gitignore so it never enters version control
3. Use a secrets manager (AWS Secrets Manager, HashiCorp Vault, etc.) instead of a flat file
4. Enable SSL/TLS for the database connection (sslmode=verify-full)
5. Use a dedicated database user with minimal privileges (not a superuser)
</details>

**Q4 (Theoretical):** Explain the difference between ON DELETE CASCADE and ON DELETE RESTRICT. Give a real-world scenario where using the wrong one causes data loss.

<details>
<summary>Answer</summary>
CASCADE automatically deletes child rows when the parent is deleted. RESTRICT prevents the parent from being deleted if children exist. Scenario: if the books-to-author foreign key used CASCADE instead of RESTRICT, deleting an author would automatically delete all their books, which would CASCADE further to delete all order_items referencing those books (since order_items.book_id uses RESTRICT, this would actually be blocked — but if it were CASCADE too, you would lose purchase history). The safe default is RESTRICT; only use CASCADE when the child rows are meaningless without their parent (like order_items without their order).
</details>

**Q5 (Practical):** Write a SQL query that finds all books that have NEVER been ordered. Which query pattern from this lesson would you use?

<details>
<summary>Answer</summary>
Use the LEFT JOIN + WHERE IS NULL pattern (same as customers_with_no_orders):

```sql
SELECT b.title, b.isbn, a.name AS author
FROM books b
JOIN authors a ON a.id = b.author_id
LEFT JOIN order_items oi ON oi.book_id = b.id
WHERE oi.id IS NULL
ORDER BY b.title;
```

This returns all books from the left side, and where there is no matching order_item, the oi columns are NULL. Filtering on WHERE oi.id IS NULL gives only the unordered books.
</details>

---

*Lesson created by da-mentor for the database learning journey.*
