-- Reverse the updates by setting hidden back to 0
UPDATE accounts
SET hidden = 0
WHERE
    hidden = 1
    AND guid IN (SELECT guid FROM v_zero_balance_leaf_accounts);
