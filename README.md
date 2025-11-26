
# ACID Properties


This repository contains a comprehensive SQL script demonstrating the **ACID properties** (Atomicity, Consistency, Isolation, Durability) in MySQL transactions. The script uses practical examples like bank transfers, balance checks, and concurrent operations to illustrate how databases ensure reliable and predictable behavior.

The goal is to provide a practical, real-world understanding of how database transactions preserve data reliability.

## Features

- **Atomicity**: "All or nothing" transfers with rollback on failure.
- **Consistency**: Enforce business rules via triggers and constraints.
- **Isolation**: Explore different isolation levels (Read Uncommitted, Read Committed, Repeatable Read, Serializable).
- **Durability**: Audit logging to ensure committed changes persist.
- **Advanced Scenarios**: Nested transactions with savepoints and concurrent bulk processing.

## Setup

1. **Create a MySQL Database**:
   ```sql
   CREATE DATABASE banking_db;
   USE banking_db;
   ```

2. **Set Up Sample Tables**:
   The script assumes the following tables exist.

   ```sql
   -- Accounts table
   CREATE TABLE accounts (
       account_id INT PRIMARY KEY AUTO_INCREMENT,
       customer_id INT,
       account_number VARCHAR(20) UNIQUE,
       account_type ENUM('checking', 'savings'),
       balance DECIMAL(15,2) DEFAULT 0.00,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Insert sample data
   INSERT INTO accounts (customer_id, account_number, account_type, balance) VALUES
   (1, 'ACC000001', 'checking', 10000.00),
   (2, 'ACC000002', 'checking', 5000.00);

   -- Customers table
   CREATE TABLE customers (
       customer_id INT PRIMARY KEY AUTO_INCREMENT,
       first_name VARCHAR(50),
       last_name VARCHAR(50),
       email VARCHAR(100) UNIQUE,
       phone VARCHAR(20),
       status ENUM('active', 'inactive') DEFAULT 'active',
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Insert sample data
   INSERT INTO customers (first_name, last_name, email, phone) VALUES
   ('John', 'Doe', 'john.doe@email.com', '555-1234');

   -- Transactions table
   CREATE TABLE transactions (
       transaction_id INT PRIMARY KEY AUTO_INCREMENT,
       from_account_id INT,
       to_account_id INT,
       transaction_type VARCHAR(20),
       amount DECIMAL(15,2),
       description TEXT,
       status ENUM('completed', 'failed', 'pending') DEFAULT 'pending',
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Customer Products table (for advanced scenario)
   CREATE TABLE customer_products (
       id INT PRIMARY KEY AUTO_INCREMENT,
       customer_id INT,
       product_id INT,
       amount DECIMAL(15,2),
       status ENUM('active', 'inactive') DEFAULT 'active'
   );

   -- Insert sample products
   INSERT INTO customer_products (customer_id, product_id, amount) VALUES
   (1, 1, 1000.00);
   ```

## Usage

### 1. Atomicity - All or Nothing
This demonstrates a bank transfer procedure that debits one account and credits another. If any step fails (e.g., insufficient funds), the entire transaction rolls back.
If transferring $100 from Account A to B, both accounts update completely, or nothing happens if one step fails (e.g., due to a network error). Prevents "half-transfers."

- **Key Code**: `CALL atomic_transfer(1, 2, 200.00);`
- **Expected Output**: Success message or error with rollback.


### 2. Consistency - Database Remains in Valid State
This property uses a trigger to enforce rules like no negative balances or exceeding limits.

- **Test**: Attempt an invalid update (e.g., `UPDATE accounts SET balance = -100.00 WHERE account_id = 1;`). It should raise an error.
- **Expected Output**: SQLSTATE error message.


### 3. Isolation - Transactions Don't Interfere
Explores MySQL's isolation levels. Run in separate sessions to see effects:
For example: One teller (transaction) can't see another's unfinished work, avoiding errors like approving a loan on a temporary low balance.

- **Read Uncommitted**: Sees uncommitted changes from other sessions.
- **Read Committed**: Only sees committed changes.
- **Repeatable Read** (MySQL default): Prevents phantom reads.
- **Serializable**: Full locking for highest isolation.

- **Reset**: `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;`


### 4. Durability - Committed Changes Persist
Creates an audit log table and demonstrates committing changes that survive restarts.
For Example: After saving a $100 transfer, it's stored on disk—not lost in a power outage. Recovery tools bring it back if needed.

- **Key Code**: Insert into `audit_log` and commit.
- **Test**: Query `SELECT * FROM audit_log ORDER BY change_date DESC LIMIT 5;`.

### 5. TCL Scenarios
- **Nested Transactions with Savepoints**: Simulates multi-level operations (e.g., customer registration → account creation → product assignment) with partial rollbacks.
- **Concurrent Transaction Management**: Bulk processing with cursors and locks for safe concurrent updates.

- **Example**: `CALL process_bulk_transfer();`

## Examples

### Running Atomic Transfer
```sql
CALL atomic_transfer(1, 2, 200.00);
-- Output: 'Transfer completed successfully'
-- Verify: SELECT balance FROM accounts WHERE account_id IN (1, 2);
```

### Testing Isolation (Multi-Session)
- **Session 1**:
  ```sql
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
  START TRANSACTION;
  SELECT balance FROM accounts WHERE account_id = 1;
  ```
- **Session 2** (concurrent):
  ```sql
  START TRANSACTION;
  UPDATE accounts SET balance = balance + 1000 WHERE account_id = 1;
  -- Don't commit yet
  ```

## Key Summary

-  Atomicity prevents incomplete transactions and ensures safe recovery from errors. 

-  Consistency keeps the database in valid states by enforcing rules and constraints.

-  Isolation allows multiple users to perform transactions simultaneously without conflicts.

-  Durability makes committed changes persistent across restarts, crashes, or power loss.


#### In short, ACID makes databases robust for real-world use, like banking or e-commerce, where errors could cost money or trust. Most modern databases (e.g., MySQL) support ACID by default, but you can tune it (like with isolation levels).
