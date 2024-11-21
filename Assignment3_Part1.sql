DECLARE
    K_CR               CONSTANT CHAR(1) := 'C';
    K_DR               CONSTANT CHAR(1) := 'D';
    V_TRANSACTION_FLAG BOOLEAN;
 
    -- cursor for individual transaction
    CURSOR C_TRANSACTIONS IS
    SELECT
        *
    FROM
        NEW_TRANSACTIONS
    ORDER BY
        TRANSACTION_NO;
 
    -- do we add a second cursor for the history? - AN
BEGIN
    FOR R_TRANSACTIONS IN C_TRANSACTIONS LOOP
        V_TRANSACTION_FLAG := FALSE;
 
        -- credit transaction
        IF (R_TRANSACTIONS.TRANSACTION_TYPE = K_CR) THEN
 
            -- insert credit entry
            INSERT INTO TRANSACTION_DETAIL VALUES (
                R_TRANSACTIONS.ACCOUNT_NO,
                R_TRANSACTIONS.TRANSACTION_DATE,
                K_CR,
                R_TRANSACTIONS.TRANSACTION_AMOUNT
            );
 
            -- adjust account by adding the credit
            UPDATE ACCOUNT
            SET
                ACCOUNT_BALANCE = ACCOUNT_BALANCE + R_TRANSACTION.TRANSACTION_AMOUNT
            WHERE
                ACCOUNT_NO = R_TRANSACTION.ACCOUNT_NO;
 
            -- debit transaction
        ELSIF (R_TRANSACTIONS.TRANSACTION_TYPE = K_DR) THEN
 
            -- insert debit entry
            INSERT INTO TRANSACTION_DETAIL VALUES (
                R_TRANSACTIONS.ACCOUNT_NO,
                R_TRANSACTIONS.TRANSACTION_DATE,
                K_DR,
                R_TRANSACTIONS.TRANSACTION_AMOUNT
            );
 
            -- adjust account by subtracting the debit
            UPDATE ACCOUNT
            SET
                ACCOUNT_BALANCE = ACCOUNT_BALANCE - R_TRANSACTION.TRANSACTION_AMOUNT
            WHERE
                ACCOUNT_NO = R_TRANSACTION.ACCOUNT_NO;
 
            -- invalid transaction
        ELSE
            RAISE_APPLICATION_ERROR(-0001, R_TRANSACTIONS, TRANSACTION_TYPE
                                                           || ' is not a valid transaction');
        END IF
 -- update history
        UPDATE TRANSACTION_HISTORY
        SET
            TRANSACTION_NO,
            TRANSACTION_DATE,
            TRANSACTION_DESCRIPTION
        WHERE
            TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO
 -- add if not found
            IF SQL%ROWCOUNT = 0 THEN V_TRANSACTION_FLAG := TRUE;
        INSERT INTO TRANSACTION_HISTORY (
            TRANSACTION_NO,
            TRANSACTION_DATE,
            TRANSACTION_DESCRIPTION
        ) VALUES (
            R_TRANSACTIONS.TRANSACTION_NO,
            R_TRANSACTIONS.TRANSACTION_DATE,
            R_TRANSACTIONS.DESCRIPTION
        ) END IF;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: '
                             || SQLERRM);
END;
/