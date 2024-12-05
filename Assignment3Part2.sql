DECLARE
    -- Constants for transaction types
    K_CR CONSTANT CHAR(1) := 'C'; -- Credit
    K_DR CONSTANT CHAR(1) := 'D'; -- Debit

    -- Debugging variable for tracking errors
    V_TRANSACTION_DEBUG_ROW NEW_TRANSACTIONS%ROWTYPE;

    e_invalid_transaction EXCEPTION;

    V_TRANSACTION_ERROR_MESSAGE VARCHAR2(200);

    V_ACCOUNT_NO_EXISTS NUMBER;

    V_VALID_TRANSACTION_FLAG BOOLEAN;

    -- Cursor to process transactions from NEW_TRANSACTIONS
    CURSOR C_TRANSACTIONS IS
        SELECT *
        FROM NEW_TRANSACTIONS
        ORDER BY TRANSACTION_NO;

BEGIN
    -- Loop through each transaction
    FOR R_TRANSACTIONS IN C_TRANSACTIONS LOOP
        -- Initialize debugging info
        V_TRANSACTION_DEBUG_ROW := R_TRANSACTIONS;

        V_VALID_TRANSACTION_FLAG := TRUE;
        --Error tracking
        BEGIN
            --Null PK
            IF R_TRANSACTIONS.TRANSACTION_NO IS NULL THEN
                V_TRANSACTION_ERROR_MESSAGE := 'Transaction ID is NULL';
                RAISE e_invalid_transaction;
            END IF;
            --Debits and Credits are not equal
            
            --Wrong account numbers
            SELECT COUNT(*) INTO V_ACCOUNT_NO_EXISTS 
            FROM ACCOUNT 
            WHERE ACCOUNT_NO = R_TRANSACTIONS.ACCOUNT_NO;

            IF V_ACCOUNT_NO_EXISTS = 0 THEN
                V_TRANSACTION_ERROR_MESSAGE := 'Acount ID is not found: ' || R_TRANSACTIONS.ACCOUNT_NO;
                RAISE e_invalid_transaction;
            END IF;
            --Negative transaction numbers
            IF R_TRANSACTIONS.TRANSACTION_AMOUNT < 0 THEN
                V_TRANSACTION_ERROR_MESSAGE := 'Transaction amount is negative: ' || R_TRANSACTIONS.TRANSACTION_AMOUNT;
                RAISE e_invalid_transaction;
            END IF;
            --Invalid transaction types
            IF R_TRANSACTIONS.TRANSACTION_TYPE NOT IN (K_CR, K_DR) THEN
                V_TRANSACTION_ERROR_MESSAGE := 'Invalid transaction type: ' || R_TRANSACTIONS.TRANSACTION_TYPE;
                RAISE e_invalid_transaction;
            END IF;
        EXCEPTION
            -- Handling wrong transactions
            WHEN e_invalid_transaction THEN
                INSERT INTO WKIS_ERROR_LOG (TRANSACTION_NO, TRANSACTION_DATE, DESCRIPTION, ERROR_MSG)
                VALUES (V_TRANSACTION_DEBUG_ROW.TRANSACTION_NO, V_TRANSACTION_DEBUG_ROW.TRANSACTION_DATE, 
                        V_TRANSACTION_DEBUG_ROW.DESCRIPTION, V_TRANSACTION_ERROR_MESSAGE);
                DELETE FROM NEW_TRANSACTIONS 
                WHERE TRANSACTION_NO = V_TRANSACTION_DEBUG_ROW.TRANSACTION_NO;
            V_VALID_TRANSACTION_FLAG := FALSE;
        END;

        IF V_VALID_TRANSACTION_FLAG = TRUE THEN

            -- Update TRANSACTION_HISTORY: Update if exists, Insert if not
            UPDATE TRANSACTION_HISTORY
            SET
                TRANSACTION_DATE = R_TRANSACTIONS.TRANSACTION_DATE,
                DESCRIPTION = R_TRANSACTIONS.DESCRIPTION
            WHERE TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO;

            IF SQL%ROWCOUNT = 0 THEN
                -- Insert new transaction history if no update occurred
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

            -- Process transaction based on type (Credit or Debit)
            IF R_TRANSACTIONS.TRANSACTION_TYPE = K_CR THEN
                -- Insert into TRANSACTION_DETAIL
                INSERT INTO TRANSACTION_DETAIL (
                    ACCOUNT_NO,
                    TRANSACTION_NO,
                    TRANSACTION_TYPE,
                    TRANSACTION_AMOUNT
                ) VALUES (
                    R_TRANSACTIONS.ACCOUNT_NO,
                    R_TRANSACTIONS.TRANSACTION_NO,
                    K_CR,
                    R_TRANSACTIONS.TRANSACTION_AMOUNT
                );

                -- Update account balance (Credit increases balance)
                UPDATE ACCOUNT
                SET ACCOUNT_BALANCE = ACCOUNT_BALANCE + R_TRANSACTIONS.TRANSACTION_AMOUNT
                WHERE ACCOUNT_NO = R_TRANSACTIONS.ACCOUNT_NO;

            ELSIF R_TRANSACTIONS.TRANSACTION_TYPE = K_DR THEN
                -- Insert into TRANSACTION_DETAIL
                INSERT INTO TRANSACTION_DETAIL (
                    ACCOUNT_NO,
                    TRANSACTION_NO,
                    TRANSACTION_TYPE,
                    TRANSACTION_AMOUNT
                ) VALUES (
                    R_TRANSACTIONS.ACCOUNT_NO,
                    R_TRANSACTIONS.TRANSACTION_NO,
                    K_DR,
                    R_TRANSACTIONS.TRANSACTION_AMOUNT
                );

                -- Update account balance (Debit decreases balance)
                UPDATE ACCOUNT
                SET ACCOUNT_BALANCE = ACCOUNT_BALANCE - R_TRANSACTIONS.TRANSACTION_AMOUNT
                WHERE ACCOUNT_NO = R_TRANSACTIONS.ACCOUNT_NO;
            END IF;

            -- Delete transaction after processing
            DELETE FROM NEW_TRANSACTIONS
            WHERE TRANSACTION_NO = R_TRANSACTIONS.TRANSACTION_NO
            AND TRANSACTION_TYPE = R_TRANSACTIONS.TRANSACTION_TYPE;

        END IF;
    END LOOP;
    -- Commit changes
    COMMIT;

EXCEPTION
    -- Exception handling with detailed error logging
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in Transaction No: ' || V_TRANSACTION_DEBUG_ROW.TRANSACTION_NO || 
                             ' Type: ' || V_TRANSACTION_DEBUG_ROW.TRANSACTION_TYPE || 
                             ' - ' || SQLERRM);
        ROLLBACK;
END;
/
