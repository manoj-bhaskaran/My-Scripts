-- Reverse the updates by setting hidden back to 0
UPDATE accounts 
SET hidden = 0 
WHERE hidden = 1 
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
    )
    -- Select leaf accounts with zero balance
    SELECT a.guid
    FROM account_tree a
    LEFT JOIN accounts children ON a.guid = children.parent_guid
    JOIN zero_balance_accounts z ON a.guid = z.account_guid
    WHERE children.guid IS NULL  -- Ensures it is a leaf account
);
