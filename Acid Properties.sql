
/* =====================================================================
					ACID PROPERTIES DEMONSTRATION IN TCL
   ===================================================================== */


/* =====================================================================
                   ATOMICITY - All or Nothing
Atomicity (“all or nothing”)
A transaction is indivisible: either everything happens, or nothing happens.
Example: If you transfer ₦5,000, the debit (from your account) and credit (to friend’s account)
both must happen together. If one fails, both are rolled back. 
 ======================================================================== */

-- Example: Bank transfer that should be atomic
DELIMITER //
CREATE PROCEDURE atomic_transfer(
    IN from_acc INT,
    IN to_acc INT, 
    IN transfer_amount DECIMAL(15,2)
)
proc_label: BEGIN
    DECLARE from_balance DECIMAL(15,2);
    DECLARE exit_code INT DEFAULT 0;
    
    -- Error handling for any database errors
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        SET exit_code = 1;
        ROLLBACK;
        SELECT 'Error occurred, transaction rolled back' AS result;
    END;
    
    START TRANSACTION;
    
    -- Check sender's balance
    SELECT balance INTO from_balance 
    FROM accounts 
    WHERE account_id = from_acc FOR UPDATE;
    
    -- Debug: Show balance and amount
    SELECT from_balance, transfer_amount AS debug_values;
    
    -- Check if sender account exists
    IF from_balance IS NULL THEN
        SET exit_code = 1;
        ROLLBACK;
        SELECT 'Sender account not found' AS result;
        LEAVE proc_label;
    END IF;
    
    -- Check for sufficient funds
    IF from_balance < transfer_amount THEN
        SET exit_code = 1;
        ROLLBACK;
        SELECT 'Insufficient funds' AS result;
        LEAVE proc_label;
    END IF;
    
    -- Debit sender
    UPDATE accounts 
    SET balance = balance - transfer_amount 
    WHERE account_id = from_acc;
    
    -- Credit receiver
    UPDATE accounts 
    SET balance = balance + transfer_amount 
    WHERE account_id = to_acc;
    
    -- Log transaction
    INSERT INTO transactions (from_account_id, to_account_id, transaction_type, amount, description, status)
    VALUES (from_acc, to_acc, 'transfer', transfer_amount, 'Atomic transfer', 'completed');
    
    IF exit_code = 0 THEN
        COMMIT;
        SELECT 'Transfer completed successfully' AS result;
    END IF;
END proc_label //
DELIMITER ;

-- Test the atomic transfer
CALL atomic_transfer(1, 2, 200.00);



/* =====================================================================
			 CONSISTENCY - Database remains in valid state
Consistency (“rules are never broken”)
A transaction must leave the database in a valid state, following all rules.
Example: If your account has ₦10,000, you can’t withdraw ₦15,000. 
The database enforces rules like no negative balances.
 ======================================================================== */

-- Example: Enforce business rules with constraints and triggers
DELIMITER //
CREATE TRIGGER check_balance_consistency 
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF NEW.balance < 0 THEN
        SIGNAL SQLSTATE '45000'  -- generic error msg
        SET MESSAGE_TEXT = 'Account balance cannot be negative';
    END IF;
    
    IF NEW.balance > 1000000 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Account balance exceeds maximum limit';
    END IF;
END //
DELIMITER ;

-- Test consistency check
START TRANSACTION;
-- This should fail due to negative balance
UPDATE accounts SET balance = -100.00 WHERE account_id = 1;
ROLLBACK;



/* =====================================================================
		 ISOLATION - Transactions don't interfere with each other
Isolation (“no interference”)
When multiple transactions run at the same time, each one behaves as if 
it’s running alone — they don’t interfere with each other.
Example: If you’re depositing ₦5,000 while a friend is withdrawing ₦2,000,
each transaction acts like it’s happening alone —the final balance will be correct.
 ======================================================================== */

-- Demonstrate isolation levels
-- Session 1: Read Uncommitted (can see uncommitted changes)
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;
SELECT balance FROM accounts WHERE account_id = 1;
-- In another session, start transaction and update but don't commit
-- This session would see the uncommitted change
ROLLBACK;

-- Session 2: Read Committed (cannot see uncommitted changes)
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;
SELECT balance FROM accounts WHERE account_id = 1;
-- In another session, update but don't commit
-- This session won't see the uncommitted change
ROLLBACK;

-- Session 3: Repeatable Read (prevents phantom reads)
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;
SELECT COUNT(*) FROM accounts WHERE balance > 5000;
-- Another session adds new account with balance > 5000
SELECT COUNT(*) FROM accounts WHERE balance > 5000;
-- Count should be the same (no phantom read)
ROLLBACK;

-- Session 4: Serializable (highest isolation)
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;
SELECT * FROM accounts WHERE account_type = 'checking';
-- Any concurrent modifications to checking accounts will be blocked
ROLLBACK;

-- Reset to default isolation level
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;



/* =====================================================================
			 DURABILITY - Committed changes persist
Durability (“once saved, it stays saved”)
Durability guarantees that committed data stays safe forever, no matter what happens to the system.
Once a transaction is committed, the changes are permanent, even if there’s a crash or power outage.
Example: If you deposit ₦5,000 and commit, after a server restart your balance will still show ₦15,000.
 ======================================================================== */

-- Example: Ensure transaction survives system restart
START TRANSACTION;

-- Create audit log for durability 
CREATE TABLE IF NOT EXISTS audit_log (   -- This table is like a black box recorder
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50),
    operation VARCHAR(20),
    record_id INT,
    old_values JSON,
    new_values JSON,
    changed_by VARCHAR(100),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert audit record
INSERT INTO audit_log (table_name, operation, record_id, new_values, changed_by)
VALUES ('accounts', 'balance_update', 1, JSON_OBJECT('balance', 5000.00), 'system');

-- Force a write to disk
COMMIT;

-- Even after system restart, this record will persist
SELECT * FROM audit_log ORDER BY change_date DESC LIMIT 5;



/* =====================================================================
     ADVANCED TCL SCENARIOS
     Nested Transactions with Savepoints
   ===================================================================== */

START TRANSACTION;

-- Level 1: Customer registration
INSERT INTO customers (first_name, last_name, email, phone, status)
VALUES ('Enoch', 'Emerald', 'enoch.emerald@email.com', '555-9999', 'active');

SET @new_customer_id = LAST_INSERT_ID();
SAVEPOINT customer_created;

-- Level 2: Account creation
INSERT INTO accounts (customer_id, account_number, account_type, balance)
VALUES (@new_customer_id, 'ACC020002', 'checking', 5000.00);

SET @new_account_id = LAST_INSERT_ID();
SAVEPOINT account_created;

-- Level 3: Product assignment (might fail)
INSERT INTO customer_products (customer_id, product_id, amount, status)
VALUES (@new_customer_id, 999, 5000.00, 'active'); -- Invalid product_id

-- This will fail, rollback to account_created savepoint
ROLLBACK TO SAVEPOINT account_created;

-- Continue with valid product assignment
INSERT INTO customer_products (customer_id, product_id, amount, status)
VALUES (@new_customer_id, 1, 5000.00, 'active');

COMMIT;


--  Concurrent Transaction Management
-- =====================================================================
-- Simulate concurrent access with locking
DELIMITER //
CREATE PROCEDURE process_bulk_transfer()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE acc_id INT;
    DECLARE acc_balance DECIMAL(15,2);
    
    -- Cursor for processing accounts
    DECLARE account_cursor CURSOR FOR
        SELECT account_id, balance 
        FROM accounts 
        WHERE account_type = 'checking' AND balance > 1000
        FOR UPDATE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    OPEN account_cursor;
    
    transfer_loop: LOOP
        FETCH account_cursor INTO acc_id, acc_balance;
        
        IF done THEN
            LEAVE transfer_loop;
        END IF;
        
        -- Process each account
        UPDATE accounts 
        SET balance = balance - 10.00 
        WHERE account_id = acc_id;
        
        INSERT INTO transactions (from_account_id, transaction_type, amount, description, status)
        VALUES (acc_id, 'fee', 10.00, 'Monthly maintenance fee', 'completed');
        
    END LOOP;
    
    CLOSE account_cursor;
    COMMIT;
    
    SELECT 'Bulk transfer completed' as result;
END //
DELIMITER ;

-- Execute bulk transfer
CALL process_bulk_transfer();
