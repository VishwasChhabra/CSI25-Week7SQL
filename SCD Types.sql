-- ------------------------------------------------------------------------
-- I've written all tables and stored procedures used in readme.md file. -- 
-- ------------------------------------------------------------------------


-- Base Customer Table for SCD Demonstrations

CREATE TABLE Customer (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100)
);

INSERT INTO Customer (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email) VALUES
(101, 'Rahul', 'Sharma', 'Mumbai', 'Maharashtra', '9876543210', 'rahul.sharma@example.com'),
(102, 'Priya', 'Singh', 'Delhi', 'Delhi', '9988776655', 'priya.singh@example.com'),
(103, 'Amit', 'Kumar', 'Bengaluru', 'Karnataka', '9123456789', 'amit.kumar@example.com');

-- -------------------------------------
-- SCD 0
-- -------------------------------------

DELIMITER //

CREATE PROCEDURE add_new_customer_if_not_exists (
    IN p_CustomerID   INT,
    IN p_FirstName    VARCHAR(100),
    IN p_LastName     VARCHAR(100),
    IN p_City         VARCHAR(100),
    IN p_State        VARCHAR(100),
    IN p_PhoneNumber  VARCHAR(15),
    IN p_Email        VARCHAR(100)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
    FROM Customer
    WHERE CustomerID = p_CustomerID;

    IF v_exists = 0 THEN
        INSERT INTO Customer (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email)
        VALUES (p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email);

        SELECT 'New customer inserted (SCD Type 0).' AS Message;
    ELSE
        -- Do nothing if the customer exists
        SELECT 'Customer already exists. No changes applied.' AS Message;
    END IF;
END //

DELIMITER ;


-- --------------------------------------------
-- SCD 1
-- --------------------------------------------


DELIMITER //

DROP PROCEDURE IF EXISTS update_or_add_customer //
CREATE PROCEDURE update_or_add_customer (
    IN p_CustomerID   INT,
    IN p_FirstName    VARCHAR(100),
    IN p_LastName     VARCHAR(100),
    IN p_City         VARCHAR(100),
    IN p_State        VARCHAR(100),
    IN p_PhoneNumber  VARCHAR(15),
    IN p_Email        VARCHAR(100)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    SELECT COUNT(*) INTO v_exists
    FROM Customer
    WHERE CustomerID = p_CustomerID;

    IF v_exists > 0 THEN
        UPDATE Customer
        SET
            FirstName   = p_FirstName,
            LastName    = p_LastName,
            City        = p_City,
            State       = p_State,
            PhoneNumber = p_PhoneNumber,
            Email       = p_Email
        WHERE CustomerID = p_CustomerID;

        SELECT 'Customer updated (SCD Type 1 overwrite).' AS Message;
    ELSE
        INSERT INTO Customer (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email)
        VALUES (p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email);

        SELECT 'New customer inserted (initial load for SCD Type 1).' AS Message;
    END IF;
END //

DELIMITER ;


-- --------------------------------------------
-- SCD 2
-- --------------------------------------------

CREATE TABLE CustomerSCD2 (
    CustomerSCD2Key INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,                        
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100),
    StartDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    EndDate DATETIME DEFAULT NULL,
    IsCurrent TINYINT(1) DEFAULT 1                  -- 1 for current, 0 for historical
);

DELIMITER //

CREATE PROCEDURE manage_customer_history (
    IN p_CustomerID   INT,
    IN p_FirstName    VARCHAR(100),
    IN p_LastName     VARCHAR(100),
    IN p_City         VARCHAR(100),
    IN p_State        VARCHAR(100),
    IN p_PhoneNumber  VARCHAR(15),
    IN p_Email        VARCHAR(100)
)
BEGIN
    DECLARE v_CurrentDate DATETIME DEFAULT NOW();
    DECLARE v_MaxEndDate DATETIME DEFAULT '9999-12-31 23:59:59';
    DECLARE v_City VARCHAR(100);
    DECLARE v_State VARCHAR(100);
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_exists
    FROM CustomerSCD2
    WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

    IF v_exists > 0 THEN
        SELECT City, State
        INTO v_City, v_State
        FROM CustomerSCD2
        WHERE CustomerID = p_CustomerID AND IsCurrent = 1
        ORDER BY StartDate DESC
        LIMIT 1;

        IF (v_City <> p_City OR v_State <> p_State) THEN
            -- 1. Expire old record
            UPDATE CustomerSCD2
            SET EndDate = DATE_SUB(v_CurrentDate, INTERVAL 1 SECOND),
                IsCurrent = 0
            WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

            -- 2. Insert new record
            INSERT INTO CustomerSCD2 
                (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email, StartDate, EndDate, IsCurrent)
            VALUES 
                (p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email, v_CurrentDate, v_MaxEndDate, 1);

            SELECT 'Customer record updated (SCD Type 2: new version added).' AS Message;
        ELSE
            UPDATE CustomerSCD2
            SET FirstName = p_FirstName,
                LastName = p_LastName,
                PhoneNumber = p_PhoneNumber,
                Email = p_Email
            WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

            SELECT 'Customer record updated (SCD Type 1 attributes on current SCD2 row).' AS Message;
        END IF;
    ELSE
        -- Insert new record
        INSERT INTO CustomerSCD2 
            (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email, StartDate, EndDate, IsCurrent)
        VALUES 
            (p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email, v_CurrentDate, v_MaxEndDate, 1);

        SELECT 'New customer inserted (SCD Type 2 initial load).' AS Message;
    END IF;
END //

DELIMITER ;


-- --------------------------------------------
-- SCD 3
-- --------------------------------------------


CREATE TABLE CustomerSCD3 (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    CurrentCity VARCHAR(100),
    PreviousCity VARCHAR(100), -- New column for SCD Type 3
    State VARCHAR(100),
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100)
);

INSERT INTO CustomerSCD3 (CustomerID, FirstName, LastName, CurrentCity, PreviousCity, State, PhoneNumber, Email) VALUES
(201, 'Neha', 'Sharma', 'Jaipur', NULL, 'Rajasthan', '7788990011', 'neha.sharma@example.com'),
(202, 'Rajesh', 'Kumar', 'Lucknow', NULL, 'Uttar Pradesh', '6655443322', 'rajesh.kumar@example.com');


DELIMITER //

CREATE PROCEDURE update_customer_city_history (
    IN p_CustomerID   INT,
    IN p_FirstName    VARCHAR(100),
    IN p_LastName     VARCHAR(100),
    IN p_NewCity      VARCHAR(100),
    IN p_State        VARCHAR(100),
    IN p_PhoneNumber  VARCHAR(15),
    IN p_Email        VARCHAR(100)
)
BEGIN
    DECLARE v_OldCity VARCHAR(100);
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
    FROM CustomerSCD3
    WHERE CustomerID = p_CustomerID;

    IF v_exists > 0 THEN
        SELECT CurrentCity INTO v_OldCity
        FROM CustomerSCD3
        WHERE CustomerID = p_CustomerID;

        UPDATE CustomerSCD3
        SET
            FirstName    = p_FirstName,
            LastName     = p_LastName,
            PreviousCity = v_OldCity,   -- Store old city
            CurrentCity  = p_NewCity,   -- Update to new city
            State        = p_State,
            PhoneNumber  = p_PhoneNumber,
            Email        = p_Email
        WHERE CustomerID = p_CustomerID;

        SELECT 'Customer updated (SCD Type 3).' AS Message;
    ELSE
        INSERT INTO CustomerSCD3
            (CustomerID, FirstName, LastName, CurrentCity, PreviousCity, State, PhoneNumber, Email)
        VALUES
            (p_CustomerID, p_FirstName, p_LastName, p_NewCity, NULL, p_State, p_PhoneNumber, p_Email);

        SELECT 'New customer inserted (SCD Type 3 initial load).' AS Message;
    END IF;
END //

DELIMITER ;


-- --------------------------------------------
-- SCD 4
-- --------------------------------------------


CREATE TABLE CustomerSCD4Current (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100)
);

CREATE TABLE CustomerSCD4History (
    CustomerHistoryID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT,
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    City VARCHAR(100),
    State VARCHAR(100),
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100),
    ChangeDate DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO CustomerSCD4Current (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email) VALUES
(301, 'Sandeep', 'Reddy', 'Hyderabad', 'Telangana', '9900112233', 'sandeep.reddy@example.com'),
(302, 'Pooja', 'Das', 'Kolkata', 'West Bengal', '9877665544', 'pooja.das@example.com');


DELIMITER //

CREATE PROCEDURE update_customer_with_history (
    IN p_CustomerID   INT,
    IN p_FirstName    VARCHAR(100),
    IN p_LastName     VARCHAR(100),
    IN p_City         VARCHAR(100),
    IN p_State        VARCHAR(100),
    IN p_PhoneNumber  VARCHAR(15),
    IN p_Email        VARCHAR(100)
)
BEGIN
    DECLARE v_CurrentDate DATETIME DEFAULT NOW();
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_changed INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists
    FROM CustomerSCD4Current
    WHERE CustomerID = p_CustomerID;

    IF v_exists > 0 THEN
        SELECT COUNT(*) INTO v_changed
        FROM CustomerSCD4Current
        WHERE CustomerID = p_CustomerID
          AND (FirstName <> p_FirstName
            OR LastName <> p_LastName
            OR City <> p_City
            OR State <> p_State
            OR PhoneNumber <> p_PhoneNumber
            OR Email <> p_Email);

        IF v_changed > 0 THEN
            INSERT INTO CustomerSCD4History
                (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email, ChangeDate)
            SELECT CustomerID, FirstName, LastName, City, State, PhoneNumber, Email, v_CurrentDate
            FROM CustomerSCD4Current
            WHERE CustomerID = p_CustomerID;

            UPDATE CustomerSCD4Current
            SET FirstName   = p_FirstName,
                LastName    = p_LastName,
                City        = p_City,
                State       = p_State,
                PhoneNumber = p_PhoneNumber,
                Email       = p_Email
            WHERE CustomerID = p_CustomerID;

            SELECT 'Customer record updated (SCD Type 4: old version moved to history, current updated).' AS Message;
        ELSE
            SELECT 'No changes detected for customer (SCD Type 4).' AS Message;
        END IF;
    ELSE
        INSERT INTO CustomerSCD4Current
            (CustomerID, FirstName, LastName, City, State, PhoneNumber, Email)
        VALUES
            (p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email);

        SELECT 'New customer inserted (SCD Type 4 initial load).' AS Message;
    END IF;
END //

DELIMITER ;

-- --------------------------------------------
-- SCD 6
-- --------------------------------------------

CREATE TABLE CustomerSCD6 (
    CustomerSCD6Key INT AUTO_INCREMENT PRIMARY KEY, 
    CustomerID INT NOT NULL,                       
    FirstName VARCHAR(100),
    LastName VARCHAR(100),

    -- SCD Type 2 attributes (tracked with StartDate, EndDate, IsCurrent)
    City VARCHAR(100),
    State VARCHAR(100),

    -- SCD Type 1 attributes (always updated on the current record)
    PhoneNumber VARCHAR(15),
    Email VARCHAR(100),

    -- SCD Type 3 attribute (Current and Previous Tier)
    CurrentCustomerTier VARCHAR(50),
    PreviousCustomerTier VARCHAR(50),

    StartDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    EndDate DATETIME DEFAULT NULL,
    IsCurrent TINYINT(1) DEFAULT 1
);

DELIMITER //

CREATE PROCEDURE manage_customer_scd6 (
    IN p_CustomerID INT,
    IN p_FirstName VARCHAR(100),
    IN p_LastName VARCHAR(100),
    IN p_City VARCHAR(100),
    IN p_State VARCHAR(100),
    IN p_PhoneNumber VARCHAR(15),
    IN p_Email VARCHAR(100),
    IN p_NewCustomerTier VARCHAR(50)
)
BEGIN
    DECLARE v_CurrentDate DATETIME DEFAULT NOW();
    DECLARE v_MaxEndDate DATETIME DEFAULT '9999-12-31 23:59:59';
    DECLARE v_ExistingCustomerTier VARCHAR(50);
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_city_state_changed INT DEFAULT 0;

    SELECT COUNT(*)
    INTO v_exists
    FROM CustomerSCD6
    WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

    IF v_exists > 0 THEN
        SELECT CurrentCustomerTier INTO v_ExistingCustomerTier
        FROM CustomerSCD6
        WHERE CustomerID = p_CustomerID AND IsCurrent = 1
        ORDER BY StartDate DESC
        LIMIT 1;

        SELECT COUNT(*) INTO v_city_state_changed
        FROM CustomerSCD6
        WHERE CustomerID = p_CustomerID AND IsCurrent = 1
          AND (City <> p_City OR State <> p_State);

        IF v_city_state_changed > 0 THEN
            UPDATE CustomerSCD6
            SET EndDate = v_CurrentDate,
                IsCurrent = 0
            WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

            INSERT INTO CustomerSCD6 (
                CustomerID, FirstName, LastName, City, State, PhoneNumber, Email,
                CurrentCustomerTier, PreviousCustomerTier, StartDate, EndDate, IsCurrent
            )
            VALUES (
                p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email,
                p_NewCustomerTier,
                CASE WHEN v_ExistingCustomerTier <> p_NewCustomerTier THEN v_ExistingCustomerTier ELSE NULL END,
                v_CurrentDate, v_MaxEndDate, 1
            );

            SELECT 'Customer record updated (SCD Type 6: new version due to City/State change).' AS Message;
        ELSE
            UPDATE CustomerSCD6
            SET FirstName = p_FirstName,
                LastName = p_LastName,
                PhoneNumber = p_PhoneNumber,
                Email = p_Email,
                PreviousCustomerTier = CASE 
                    WHEN CurrentCustomerTier <> p_NewCustomerTier THEN CurrentCustomerTier 
                    ELSE PreviousCustomerTier 
                END,
                CurrentCustomerTier = p_NewCustomerTier
            WHERE CustomerID = p_CustomerID AND IsCurrent = 1;

            SELECT 'Customer record updated (SCD Type 6: SCD1/SCD3 attributes on current row).' AS Message;
        END IF;
    ELSE
        INSERT INTO CustomerSCD6 (
            CustomerID, FirstName, LastName, City, State, PhoneNumber, Email,
            CurrentCustomerTier, PreviousCustomerTier, StartDate, EndDate, IsCurrent
        )
        VALUES (
            p_CustomerID, p_FirstName, p_LastName, p_City, p_State, p_PhoneNumber, p_Email,
            p_NewCustomerTier, NULL, v_CurrentDate, v_MaxEndDate, 1
        );

        SELECT 'New customer inserted (SCD Type 6 initial load).' AS Message;
    END IF;
END //

DELIMITER ;