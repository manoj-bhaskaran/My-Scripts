-- Update accounts to hide zero balance accounts under 'Cash Investments'
UPDATE accounts
SET hidden = 1
WHERE
    hidden = 0
    AND guid IN (SELECT guid FROM v_zero_balance_leaf_accounts);
