DROP DATABASE IF EXISTS bank_churn_project;
CREATE DATABASE bank_churn_project;
USE bank_churn_project;

DROP TABLE IF EXISTS customer_info_raw;

CREATE TABLE customer_info_raw (
    CustomerId INT,
    Surname VARCHAR(100),
    CreditScore INT,
    Geography VARCHAR(50),
    Gender VARCHAR(20),
    Age INT,
    Tenure INT,
    EstimatedSalary VARCHAR(50)
);

DROP TABLE IF EXISTS account_info_raw;

CREATE TABLE account_info_raw (
    CustomerId INT,
    Balance VARCHAR(50),
    NumOfProducts INT,
    HasCrCard VARCHAR(10),
    Tenure INT,
    IsActiveMember VARCHAR(10),
    Exited INT
);

SELECT *
FROM account_info_raw
LIMIT 10;

SELECT *
FROM customer_info_raw
LIMIT 10;

SELECT COUNT(*) AS customer_rows
FROM customer_info_raw;

SELECT COUNT(*) AS account_rows
FROM account_info_raw;

-- Check Duplicates
SELECT 
    CustomerId,
    COUNT(*) AS duplicate_count
FROM customer_info_raw
GROUP BY CustomerId
HAVING COUNT(*) > 1;

SELECT 
    CustomerId,
    COUNT(*) AS duplicate_count
FROM account_info_raw
GROUP BY CustomerId
HAVING COUNT(*) > 1;

-- Check Missing Values
SELECT
    SUM(CASE WHEN CustomerId IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN Surname IS NULL OR Surname = '' THEN 1 ELSE 0 END) AS missing_surname,
    SUM(CASE WHEN CreditScore IS NULL THEN 1 ELSE 0 END) AS missing_credit_score,
    SUM(CASE WHEN Geography IS NULL OR Geography = '' THEN 1 ELSE 0 END) AS missing_geography,
    SUM(CASE WHEN Gender IS NULL OR Gender = '' THEN 1 ELSE 0 END) AS missing_gender,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS missing_age,
    SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS missing_tenure,
    SUM(CASE WHEN EstimatedSalary IS NULL OR EstimatedSalary = '' THEN 1 ELSE 0 END) AS missing_salary
FROM customer_info_raw;

SELECT
    SUM(CASE WHEN CustomerId IS NULL THEN 1 ELSE 0 END) AS missing_customer_id,
    SUM(CASE WHEN Balance IS NULL OR Balance = '' THEN 1 ELSE 0 END) AS missing_balance,
    SUM(CASE WHEN NumOfProducts IS NULL THEN 1 ELSE 0 END) AS missing_products,
    SUM(CASE WHEN HasCrCard IS NULL OR HasCrCard = '' THEN 1 ELSE 0 END) AS missing_credit_card,
    SUM(CASE WHEN Tenure IS NULL THEN 1 ELSE 0 END) AS missing_tenure,
    SUM(CASE WHEN IsActiveMember IS NULL OR IsActiveMember = '' THEN 1 ELSE 0 END) AS missing_active_member,
    SUM(CASE WHEN Exited IS NULL THEN 1 ELSE 0 END) AS missing_exited
FROM account_info_raw;

-- Clean Customer Data
DROP TABLE IF EXISTS customer_info_clean;

CREATE TABLE customer_info_clean AS
WITH ranked_customers AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY CustomerId 
            ORDER BY CustomerId
        ) AS rn
    FROM customer_info_raw
)
SELECT
    CustomerId,

    COALESCE(NULLIF(Surname, ''), 'Unknown') AS Surname,

    CreditScore,

    CASE
        WHEN Geography IN ('FRA', 'French', 'France') THEN 'France'
        WHEN Geography = 'Spain' THEN 'Spain'
        WHEN Geography = 'Germany' THEN 'Germany'
        ELSE 'Unknown'
    END AS Geography,

    Gender,

    COALESCE(
        Age,
        (SELECT ROUND(AVG(Age)) FROM customer_info_raw WHERE Age IS NOT NULL)
    ) AS Age,

    Tenure,

    CAST(
        REPLACE(REPLACE(EstimatedSalary, '€', ''), ',', '') 
        AS DECIMAL(12,2)
    ) AS EstimatedSalary

FROM ranked_customers
WHERE rn = 1;

-- Clean Account Data
DROP TABLE IF EXISTS account_info_clean;

CREATE TABLE account_info_clean AS
WITH ranked_accounts AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY CustomerId 
            ORDER BY CustomerId
        ) AS rn
    FROM account_info_raw
)
SELECT
    CustomerId,

    CAST(
        REPLACE(REPLACE(Balance, '€', ''), ',', '') 
        AS DECIMAL(12,2)
    ) AS Balance,

    NumOfProducts,

    CASE 
        WHEN HasCrCard = 'Yes' THEN 1
        WHEN HasCrCard = 'No' THEN 0
        ELSE NULL
    END AS HasCrCard,

    Tenure,

    CASE 
        WHEN IsActiveMember = 'Yes' THEN 1
        WHEN IsActiveMember = 'No' THEN 0
        ELSE NULL
    END AS IsActiveMember,

    Exited,

    CASE 
        WHEN Exited = 1 THEN 'Churned'
        WHEN Exited = 0 THEN 'Retained'
        ELSE 'Unknown'
    END AS ChurnStatus

FROM ranked_accounts
WHERE rn = 1;

-- Create Final Analysis Table
DROP TABLE IF EXISTS bank_churn_analysis;

CREATE TABLE bank_churn_analysis AS
SELECT
    c.CustomerId,
    c.Surname,
    c.CreditScore,

    CASE
        WHEN c.CreditScore < 500 THEN 'Poor'
        WHEN c.CreditScore BETWEEN 500 AND 649 THEN 'Fair'
        WHEN c.CreditScore BETWEEN 650 AND 749 THEN 'Good'
        ELSE 'Excellent'
    END AS CreditScoreGroup,

    c.Geography,
    c.Gender,
    c.Age,

    CASE 
        WHEN c.Age < 30 THEN 'Under 30'
        WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
        WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
        WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
        ELSE '60+'
    END AS AgeGroup,

    c.Tenure AS CustomerTenure,
    c.EstimatedSalary,

    a.Balance,

    CASE
        WHEN a.Balance = 0 THEN 'Zero Balance'
        WHEN a.Balance BETWEEN 1 AND 50000 THEN 'Low Balance'
        WHEN a.Balance BETWEEN 50001 AND 100000 THEN 'Medium Balance'
        ELSE 'High Balance'
    END AS BalanceGroup,

    a.NumOfProducts,
    a.HasCrCard,

    CASE 
        WHEN a.HasCrCard = 1 THEN 'Has Credit Card'
        WHEN a.HasCrCard = 0 THEN 'No Credit Card'
        ELSE 'Unknown'
    END AS CreditCardStatus,

    a.IsActiveMember,

    CASE 
        WHEN a.IsActiveMember = 1 THEN 'Active'
        WHEN a.IsActiveMember = 0 THEN 'Inactive'
        ELSE 'Unknown'
    END AS ActiveStatus,

    a.Exited,
    a.ChurnStatus

FROM customer_info_clean c
INNER JOIN account_info_clean a
    ON c.CustomerId = a.CustomerId;
    
  -- Validate Final Table
  SELECT COUNT(*) AS total_customers
FROM bank_churn_analysis;

SELECT *
FROM bank_churn_analysis
LIMIT 20;

SELECT 
    ChurnStatus,
    COUNT(*) AS customers
FROM bank_churn_analysis
GROUP BY ChurnStatus;

-- Run Main SQL Analysis Queries
SELECT
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    COUNT(*) - SUM(Exited) AS retained_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis;

SELECT
    Geography,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY Geography
ORDER BY churn_rate_percentage DESC;

SELECT
    Gender,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY Gender
ORDER BY churn_rate_percentage DESC;

SELECT
    AgeGroup,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY AgeGroup
ORDER BY churn_rate_percentage DESC;

SELECT
    ActiveStatus,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY ActiveStatus
ORDER BY churn_rate_percentage DESC;

SELECT
    NumOfProducts,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY NumOfProducts
ORDER BY NumOfProducts;

SELECT
    CreditCardStatus,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY CreditCardStatus
ORDER BY churn_rate_percentage DESC;

SELECT
    BalanceGroup,
    COUNT(*) AS total_customers,
    SUM(Exited) AS churned_customers,
    ROUND(SUM(Exited) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM bank_churn_analysis
GROUP BY BalanceGroup
ORDER BY churn_rate_percentage DESC;

