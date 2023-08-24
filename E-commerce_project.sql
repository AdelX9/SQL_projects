--RB_SQL Project
--Q1106 ADEL
--Import flat file
CREATE DATABASE Project 
GO
USE Project
--Check the data
SELECT *
FROM e_commerce_data
--Analysis
--1 Find the top 3 customers who have the maximum count of orders
SELECT TOP 3 Cust_ID, COUNT(Ord_ID) total_orders
FROM e_commerce_data
GROUP BY Ord_ID, Cust_ID
ORDER BY total_orders DESC;
--2 Find the customer whose order took the maximum time to get shipping.
SELECT  TOP 1 Cust_ID, MAX(DaysTakenForShipping) AS max_days
FROM e_commerce_data
GROUP BY Cust_ID, DaysTakenForShipping 
ORDER BY max_days DESC;
--3 Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011
SELECT DISTINCT Cust_ID -- CTE for jan customers 
FROM e_commerce_data
WHERE MONTH(Order_Date) = '01' and YEAR(Order_Date) = '2011';
--ALL months
WITH jan_cust AS(
SELECT DISTINCT Cust_ID 
FROM e_commerce_data
WHERE MONTH(Order_Date) = '01' and YEAR(Order_Date) = '2011'
)
SELECT MONTH(Order_Date) AS	Month, COUNT(DISTINCT Cust_ID) AS loyal_cust
FROM e_commerce_data
WHERE YEAR(Order_Date) = 2011 
AND MONTH(Order_Date) > 1 -- AFTER JANUARY
AND Cust_ID IN (SELECT Cust_ID FROM jan_cust)
GROUP BY MONTH(Order_Date)
ORDER BY Month;
--4 Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.
WITH cte AS(
SELECT *,
	ROW_NUMBER () OVER (PARTITION BY Cust_ID ORDER BY Order_Date) nth_order ,
	lead(Order_Date,2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date) third_ord,
	DATEDIFF(DAY,Order_Date,lead(Order_Date,2) OVER (PARTITION BY Cust_ID ORDER BY Order_Date)) day_diff
FROM (
		SELECT DISTINCT Ord_ID ,Cust_ID, Customer_Name,Order_Date
		FROM e_commerce_data
) subq
)
SELECT *
FROM cte
WHERE nth_order=1 and third_ord is not null

--5 Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of products purchased by the customer.
SELECT Cust_ID, Customer_Name,
	SUM(CASE WHEN Prod_Id = 'Prod_11' THEN Order_Quantity END) qnty_prod_11,
	SUM(CASE WHEN Prod_Id = 'Prod_14' THEN Order_Quantity END) qnty_prod_14,
	SUM(CASE WHEN Prod_Id = 'Prod_11' THEN Order_Quantity END) + SUM(CASE WHEN Prod_Id = 'Prod_14' THEN Order_Quantity END) qnty_11_14,
	SUM(Order_Quantity) qnty_total,
	(1.0*(SUM(CASE WHEN Prod_Id = 'Prod_11' THEN Order_Quantity END) + SUM(CASE WHEN Prod_Id = 'Prod_14' THEN Order_Quantity END)) / SUM(Order_Quantity)) * 100 prcnt_11_14
FROM e_commerce_data
WHERE Cust_ID IN
(	SELECT Cust_ID
	FROM e_commerce_data
	WHERE Prod_ID = 'Prod_11'
	INTERSECT
	SELECT Cust_ID
	FROM e_commerce_data
	WHERE Prod_ID = 'Prod_14'

)
GROUP BY Cust_ID, Customer_Name


--SEGMENTATION 
--1 Create a “view” that keeps visit logs of customers on a monthly basis. (For each log, three field is kept: Cust_id, Year, Month)
SELECT Ord_ID, Cust_ID, YEAR (Order_Date) [Year], MONTH(Order_Date) [Month]
FROM e_commerce_data
ORDER BY Ord_ID, Cust_ID;
--View
CREATE VIEW monthly_visit_log AS 
SELECT DISTINCT Cust_ID, YEAR(Order_Date) AS "Year", MONTH(Order_Date) AS "Month"
FROM e_commerce_data;
--show the view
SELECT *
FROM monthly_visit_log;

--2 Create a “view” that keeps the number of monthly visits by users. (Show separately all months from the beginning business)
--cust per month

DROP VIEW monthly_visit_counts; --just in case
CREATE VIEW monthly_visit_counts AS(
	SELECT *
	FROM(
		SELECT [Year], [Month], COUNT(*) AS MonthlyVisits
		FROM monthly_visit_log
		GROUP BY [Year], [Month]
		) subq
	)
SELECT * FROM monthly_visit_counts
ORDER BY [Year], [Month]

--3 For each visit of customers, create the next month of the visit as a separate column.
CREATE VIEW time_lapse AS (
	SELECT * ,
		LEAD([Year]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) next_visit_year,
		LEAD([Month]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) next_visit_month,
		LAG([Year]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) previous_visit_year,
		LAG([Month]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) previous_visit_month
	FROM monthly_visit_log
	)
SELECT * FROM time_lapse;

--4 Calculate the monthly time gap between two consecutive visits by each customer.
DROP VIEW time_diff_months
CREATE VIEW time_diff_months AS		
(
	SELECT *,
		(([Year]- previous_visit_year) * 12) + ([Month] - previous_visit_month) time_diff
	FROM time_lapse
	)

SELECT *
FROM time_diff_months

--5 Categorise customers using average time gaps. Choose the most fitted labeling model for you.
CREATE VIEW segmentation AS (
	SELECT *,
		CASE
			WHEN time_diff = 1 THEN 'regular' -- 0 indicates that a purchase was made in the same month. We are interested in those who made in the past month.
			WHEN next_visit_month IS NULL THEN 'churn'
			WHEN time_diff IS NULL THEN 'first_order'
			WHEN time_diff > 1 THEN 'lagger'	
		END AS customer_segment
	FROM time_diff_months
	) 

SELECT *
FROM segmentation

--RETENTATION RATE
--1 Find the number of customers retained month-wise.
SELECT *
FROM segmentation
WHERE [Year]=2009 AND [Month]=1 /*AND customer_segment = 'regular'*/
ORDER BY [Year], [Month]
--count the number of retained(regular) customers
SELECT DISTINCT [Year], [Month],
	SUM(CASE WHEN customer_segment = 'regular' THEN 1 END) OVER (PARTITION BY [Year], [Month] ORDER BY [Year], [Month]) count_regular
FROM segmentation
ORDER BY [Year], [Month]

--2 Calculate the month-wise retention rate.
SELECT DISTINCT [Year], [Month],
		SUM(CASE WHEN time_diff = 1 THEN 1 END) OVER (PARTITION BY [Year], [Month] ORDER BY [Year], [Month]) count_regular,
		COUNT(Ord_ID) OVER (PARTITION BY [Year], [Month] ORDER BY [Year], [Month]) count_total,
		CAST(1.0 * SUM(CASE WHEN time_diff = 1 THEN 1 END) OVER (PARTITION BY [Year], [Month] ORDER BY [Year], [Month]) / COUNT(Ord_ID) OVER (PARTITION BY [Year], [Month] ORDER BY [Year], [Month]) AS DECIMAL(5,2)) retention_rate
	FROM (
		SELECT *,
				LAG([Year]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) previous_visit_year,
				LAG([Month]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month]) previous_visit_month,
				(([Year]- LAG([Year]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month])) * 12) + ([Month] - LAG([Month]) OVER (PARTITION BY Cust_ID ORDER BY Cust_ID, [Year], [Month])) time_diff
		FROM (
			SELECT DISTINCT Ord_ID, Cust_ID, YEAR(Order_Date) AS [Year], MONTH(Order_Date) AS [Month]
			FROM e_commerce_data
			) subq1
			) subq2
	ORDER BY [Year], [Month]

