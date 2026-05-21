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
