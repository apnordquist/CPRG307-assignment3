DECLARE
    K_CR               CONSTANT CHAR(1) := 'C';
    K_DR               CONSTANT CHAR(1) := 'D';
    V_TRANSACTION_FLAG BOOLEAN;

    V_TRANSACTION_VALID_FLAG BOOLEAN;

    V_TRANSACTION_DEBUG_ROW NEW_TRANSACTIONS%ROWTYPE;

    -- cursor for individual transaction
    CURSOR C_TRANSACTIONS IS
    SELECT *
    FROM NEW_TRANSACTIONS
    ORDER BY TRANSACTION_NO;
 
    -- do we add a second cursor for the history? - AN
BEGIN
    FOR R_TRANSACTIONS IN C_TRANSACTIONS LOOP
        V_TRANSACTION_FLAG := FALSE;
        V_TRANSACTION_DEBUG_ROW := R_TRANSACTIONS;
        V_TRANSACTION_VALID_FLAG := FALSE;

        -- update history
        UPDATE TRANSACTION_HISTORY
        SET
            TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO,
            TRANSACTION_DATE = R_TRANSACTIONS.TRANSACTION_DATE,
            DESCRIPTION = R_TRANSACTIONS.DESCRIPTION
        WHERE
            TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO;
        -- add if not found
        IF SQL%ROWCOUNT = 0 THEN V_TRANSACTION_FLAG := TRUE;

            INSERT INTO TRANSACTION_HISTORY (
                TRANSACTION_NO,
                TRANSACTION_DATE,
                DESCRIPTION
            ) VALUES (
                R_TRANSACTIONS.TRANSACTION_NO,
                R_TRANSACTIONS.TRANSACTION_DATE,
                R_TRANSACTIONS.DESCRIPTION
            ); 

        END IF;

        -- credit transaction
        IF (R_TRANSACTIONS.TRANSACTION_TYPE = K_CR) THEN
            V_TRANSACTION_VALID_FLAG := TRUE;
            -- insert credit entry
            INSERT INTO TRANSACTION_DETAIL (ACCOUNT_NO, TRANSACTION_NO, TRANSACTION_TYPE, TRANSACTION_AMOUNT) VALUES (
                R_TRANSACTIONS.ACCOUNT_NO,
                R_TRANSACTIONS.TRANSACTION_NO,
                K_CR,
                R_TRANSACTIONS.TRANSACTION_AMOUNT
            );
 
            -- adjust account by adding the credit
            UPDATE ACCOUNT
            SET
                ACCOUNT_BALANCE = ACCOUNT_BALANCE + R_TRANSACTIONS.TRANSACTION_AMOUNT
            WHERE
                ACCOUNT_NO = R_TRANSACTIONS.ACCOUNT_NO;
 
        -- debit transaction
        ELSIF (R_TRANSACTIONS.TRANSACTION_TYPE = K_DR) THEN
            V_TRANSACTION_VALID_FLAG := TRUE;
            -- insert debit entry
            INSERT INTO TRANSACTION_DETAIL (ACCOUNT_NO, TRANSACTION_NO, TRANSACTION_TYPE, TRANSACTION_AMOUNT)  VALUES (
                R_TRANSACTIONS.ACCOUNT_NO,
                R_TRANSACTIONS.TRANSACTION_NO,
                K_DR,
                R_TRANSACTIONS.TRANSACTION_AMOUNT
            );
 
            -- adjust account by subtracting the debit
            UPDATE ACCOUNT
            SET
                ACCOUNT_BALANCE = ACCOUNT_BALANCE - R_TRANSACTIONS.TRANSACTION_AMOUNT
            WHERE
                ACCOUNT_NO = R_TRANSACTIONS.ACCOUNT_NO;
 
        -- invalid transaction
        ELSE
            V_TRANSACTION_FLAG := FALSE;
            RAISE_APPLICATION_ERROR(-20001, 'Transaction Type ' || R_TRANSACTIONS.TRANSACTION_TYPE || ' is not a valid transaction');

        END IF;
        
        -- Delete transaction, if correct.
        If V_TRANSACTION_VALID_FLAG = TRUE THEN

            DELETE 
            FROM NEW_TRANSACTIONS
            WHERE TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO AND TRANSACTION_TYPE = R_TRANSACTIONS.TRANSACTION_TYPE;

        END IF;
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in transaction no: ' || V_TRANSACTION_DEBUG_ROW.TRANSACTION_NO || '.' || V_TRANSACTION_DEBUG_ROW.TRANSACTION_TYPE|| ' - ' || SQLERRM);

        -- DBMS_OUTPUT.PUT_LINE('Error: '
        --                      || SQLERRM);
    ROLLBACK;
END;
/