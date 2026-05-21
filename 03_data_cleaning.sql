USE bank_churn_project;

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
        WHEN Geography = 'Germany' THEN 'Germany'
        WHEN Geography = 'Spain' THEN 'Spain'
        ELSE 'Unknown'
    END AS Geography,

    Gender,

    COALESCE(
        Age,
        (SELECT ROUND(AVG(Age))
         FROM customer_info_raw
         WHERE Age IS NOT NULL)
    ) AS Age,

    Tenure,

    CAST(
        REPLACE(REPLACE(EstimatedSalary, '€', ''), ',', '')
        AS DECIMAL(12,2)
    ) AS EstimatedSalary

FROM ranked_customers
WHERE rn = 1;

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
