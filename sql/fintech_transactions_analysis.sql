/*---------------------
1. Data import
----------------------*/

	/* Create database */
DROP DATABASE IF EXISTS fintech_portfolio;
CREATE DATABASE fintech_portfolio;
USE fintech_portfolio;

	/* Create tables */
CREATE TABLE DimProductCategory (
    ProductCategoryID INT PRIMARY KEY,
    ProductCategoryName VARCHAR(100)
);

CREATE TABLE DimProductSubCategory (
    ProductSubCategoryID INT PRIMARY KEY,
    ProductSubCategoryName VARCHAR(100),
    ProductCategoryID INT
);

CREATE TABLE DimProduct (
    ProductID INT PRIMARY KEY,
    ProductSubCategoryID INT,
    ProductName VARCHAR(100)
);

CREATE TABLE DimCustomer (
    CustomerID INT PRIMARY KEY,
    FullName VARCHAR(100),
    DOB VARCHAR(20),
    Gender VARCHAR(20),
    Region VARCHAR(50),
    Email VARCHAR(150),
    Status VARCHAR(30),
    JoinDate VARCHAR(20)
);

CREATE TABLE DimAccount (
    AccountID INT PRIMARY KEY,
    CustomerID INT,
    AccountType VARCHAR(50),
    OpenDate DATE,
    ClosedDate DATE NULL,
    Status VARCHAR(30),
    RegistrationID INT,
    Balance DECIMAL(12,2)
);

CREATE TABLE FactTransaction (
    TransactionID INT PRIMARY KEY,
    AccountID INT,
    TransactionDate VARCHAR(20),
    TransactionAmount DECIMAL(12,2),
    TransactionType VARCHAR(20),
    TransactionChannel VARCHAR(20),
    ProductID INT,
    Status VARCHAR(30)
);



/*---------------------
2. Data Cleaning & Validation
----------------------*/

	/* Check tables */
SELECT * FROM DimCustomer LIMIT 5;
SELECT * FROM DimProduct LIMIT 5;
SELECT * FROM FactTransaction LIMIT 5;
SELECT * FROM DimAccount LIMIT 5;
SELECT * FROM DimProductCategory LIMIT 5;
SELECT * FROM DimProductSubcategory LIMIT 5;

	/* Validate joins for product tables */
SELECT
t.TransactionID,
t.TransactionAmount,
p.ProductName,
psc.ProductSubCategoryName,
pc.ProductCategoryName
FROM FactTransaction t
JOIN DimProduct p
ON t.ProductID = p.ProductID
JOIN DimProductSubCategory psc
ON p.ProductSubCategoryID = psc.ProductSubCategoryID
JOIN DimProductCategory pc
ON psc.ProductCategoryID = pc.ProductCategoryID
LIMIT 10;

	/* Check for missing values in important customer fields */
SELECT *
FROM DimCustomer
WHERE FullName IS NULL
   OR Email IS NULL;

	/* Check for duplicate customer IDs */
SELECT
    CustomerID,
    COUNT(*) AS DuplicateCount
FROM DimCustomer
GROUP BY CustomerID
HAVING COUNT(*) > 1;

/* Convert TransactionDate from text to DATE */
ALTER TABLE FactTransaction
ADD COLUMN CleanTransactionDate DATE;

UPDATE FactTransaction
SET CleanTransactionDate = STR_TO_DATE(TransactionDate, '%m/%d/%Y');

ALTER TABLE FactTransaction
DROP COLUMN TransactionDate;

ALTER TABLE FactTransaction
CHANGE CleanTransactionDate TransactionDate DATE;

	/* Convert DOB and JoinDate from text to DATE */
ALTER TABLE DimCustomer
ADD COLUMN CleanDOB DATE,
ADD COLUMN CleanJoinDate DATE;

UPDATE DimCustomer
SET
    CleanDOB = STR_TO_DATE(DOB, '%d/%m/%Y'),
    CleanJoinDate = STR_TO_DATE(JoinDate, '%d/%m/%Y');

ALTER TABLE DimCustomer
DROP COLUMN DOB,
DROP COLUMN JoinDate;

ALTER TABLE DimCustomer
CHANGE CleanDOB DOB DATE,
CHANGE CleanJoinDate JoinDate DATE;

	/* Check transaction totals by type */
SELECT
    TransactionType,
    COUNT(*) AS Transactions,
    SUM(TransactionAmount) AS TotalAmount
FROM FactTransaction
GROUP BY TransactionType;

	/* Check transaction amount range by type */
SELECT
    TransactionType,
    MIN(TransactionAmount) AS MinAmount,
    MAX(TransactionAmount) AS MaxAmount
FROM FactTransaction
GROUP BY TransactionType;

	/* Check for transactions where amount sign conflicts with the dataset's transaction type pattern */
SELECT *
FROM FactTransaction
WHERE
    (TransactionType = 'Credit' AND TransactionAmount > 0)
    OR
    (TransactionType = 'Debit' AND TransactionAmount < 0);




/*---------------------
3. Data analysis
----------------------*/

/* Analyze transaction totals by product category */
SELECT
    pc.ProductCategoryName,
    COUNT(*) AS TransactionCount,
    ROUND(SUM(t.TransactionAmount), 2) AS TotalAmount,
    ROUND(AVG(t.TransactionAmount), 2) AS AvgTransactionAmount
FROM FactTransaction t
JOIN DimProduct p
    ON t.ProductID = p.ProductID
JOIN DimProductSubCategory psc
    ON p.ProductSubCategoryID = psc.ProductSubCategoryID
JOIN DimProductCategory pc
    ON psc.ProductCategoryID = pc.ProductCategoryID
GROUP BY pc.ProductCategoryName
ORDER BY TotalAmount DESC;


/* Rank products within each category */
WITH ProductSales AS (
    SELECT
        pc.ProductCategoryName,
        p.ProductName,
        COUNT(*) AS TransactionCount,
        ROUND(SUM(t.TransactionAmount), 2) AS TotalAmount
    FROM FactTransaction t
    JOIN DimProduct p
        ON t.ProductID = p.ProductID
    JOIN DimProductSubCategory psc
        ON p.ProductSubCategoryID = psc.ProductSubCategoryID
    JOIN DimProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
    GROUP BY pc.ProductCategoryName, p.ProductName
)
SELECT
    ProductCategoryName,
    ProductName,
    TransactionCount,
    TotalAmount,
    RANK() OVER (
        PARTITION BY ProductCategoryName
        ORDER BY TotalAmount DESC
    ) AS ProductRank
FROM ProductSales;


/* Segment transactions by amount range */
SELECT
    CASE
        WHEN TransactionAmount < 0 THEN 'Negative'
        WHEN TransactionAmount BETWEEN 0 AND 999 THEN 'Low'
        WHEN TransactionAmount BETWEEN 1000 AND 4999 THEN 'Medium'
        ELSE 'High'
    END AS TransactionBand,
    COUNT(*) AS TransactionCount,
    ROUND(SUM(TransactionAmount), 2) AS TotalAmount,
    ROUND(AVG(TransactionAmount), 2) AS AvgAmount
FROM FactTransaction
GROUP BY
    CASE
        WHEN TransactionAmount < 0 THEN 'Negative'
        WHEN TransactionAmount BETWEEN 0 AND 999 THEN 'Low'
        WHEN TransactionAmount BETWEEN 1000 AND 4999 THEN 'Medium'
        ELSE 'High'
    END
ORDER BY TotalAmount DESC;


/* Find transactions above average amount */
SELECT
    TransactionID,
    AccountID,
    TransactionAmount
FROM FactTransaction
WHERE TransactionAmount >
    (SELECT AVG(TransactionAmount)
     FROM FactTransaction)
ORDER BY TransactionAmount DESC
LIMIT 20;