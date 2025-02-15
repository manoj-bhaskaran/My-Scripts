-- Update accounts to hide zero balance accounts under 'Cash Investments' 
-- only if their last transaction date is greater than a specified date
UPDATE accounts 
SET hidden = 1 
WHERE hidden = 0 
AND guid IN (
    WITH RECURSIVE account_tree AS (
        -- Recursive CTE to get all accounts under 'Cash Investments'
        SELECT guid, parent_guid 
        FROM accounts 
        WHERE parent_guid = (
            SELECT guid 
            FROM accounts 
            WHERE name = 'Cash Investments'
        )
        UNION ALL
        SELECT a.guid, a.parent_guid 
        FROM accounts a
        JOIN account_tree at ON a.parent_guid = at.guid
    ),
    zero_balance_accounts AS (
        -- CTE to get accounts with zero balance
        SELECT account_guid, SUM(value_num) AS balance
        FROM splits
        GROUP BY account_guid
        HAVING SUM(value_num) = 0
    ),
    last_transaction_dates AS (
        -- CTE to get the last transaction date for each account
        SELECT s.account_guid, MAX(t.post_date) AS last_txn_date
        FROM transactions t
        JOIN splits s ON t.guid = s.tx_guid
        GROUP BY s.account_guid
    )
    -- Select leaf accounts with zero balance and last transaction date > specified date
    SELECT a.guid
    FROM account_tree a
    LEFT JOIN accounts children ON a.guid = children.parent_guid
    JOIN zero_balance_accounts z ON a.guid = z.account_guid
    JOIN last_transaction_dates l ON a.guid = l.account_guid
    WHERE children.guid IS NULL  -- Ensures it is a leaf account
    AND l.last_txn_date > 'YYYY-MM-DD'  -- Replace with the desired date
);
