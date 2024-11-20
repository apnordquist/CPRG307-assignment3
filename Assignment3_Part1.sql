DECLARE
    k_cr CONSTANT CHAR(1) := 'C';
    K_dr CONSTANT CHAR(1) := 'D';

    CURSOR c_transactions IS
        SELECT *
        FROM new_transactions
        ORDER BY transaction_no;

BEGIN

    FOR r_transactions in c_transactions LOOP

        -- debit transaction    
        IF (r_transactions.TRANSACTION_TYPE = k_cr) THEN
            -- insert credit entry
            INSERT INTO transaction_detail
            VALUES (r_transactions.ACCOUNT_NO, r_transactions.TRANSACTION_DATE, k_cr, r_transactions.TRANSACTION_AMOUNT);

            -- adjust account
            UPDATE ACCOUNT
            SET account_balance = account_balance + r_transaction.TRANSACTION_AMOUNT
            WHERE account_no = r_transaction.ACCOUNT_NO;

        -- debit transaction
        ELSIF (r_transactions.TRANSACTION_TYPE = k_dr) THEN
            -- insert debit entry
            INSERT INTO transaction_detail
            values (r_transactions.ACCOUNT_NO, r_transactions.TRANSACTION_DATE, k_dr, r_transactions.TRANSACTION_AMOUNT);

            -- adjust account
            UPDATE ACCOUNT
            SET account_balance = account_balance - r_transaction.TRANSACTION_AMOUNT
            WHERE account_no = r_transaction.ACCOUNT_NO;

        -- invalid transaction
        ELSE
            RAISE_APPLICATION_ERROR(-0001, r_transactions,TRANSACTION_TYPE || ' is not a valid transaction');

        END IF

    END LOOP;


EXCEPTION

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);

END;
/