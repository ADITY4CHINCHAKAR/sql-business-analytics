/* DAY - 14 BOSS ARENA */

/*💬 CEO (Direct message!):
"I want a monthly performance report. ONE query. Every metric I could possibly need."
For each month (delivered orders only), show ALL 14 columns:

1. month — 'Mon YYYY' format
2. revenue
3. order_count (COUNT DISTINCT order_id)
4. unique_customers that month
5. avg_order_value (revenue/orders, handle zero!)
6. revenue_per_customer (revenue/unique_customers)
7. prev_revenue (LAG)
8. mom_change_pct — (current-prev)/prev × 100 with PARENTHESES!
9. trend — '📈 Up' / '📉 Down' / '➡️ First' (NULL check FIRST in CASE!)
10. running_total — cumulative revenue
11. pct_of_total — SHARE formula (this month / grand total × 100)
12. cumulative_pct — PROGRESS formula (running / grand × 100)
13. baseline — FIRST_VALUE (first month's revenue)
14. growth_from_start — CHANGE formula vs baseline*/

 O.ORDER_ID) AS order_count,
	COUNT(DISTINCT O.CUSTOMER_ID) AS UNIQUE_CUSTOMER
FROM ORDERS O 
JOIN ORDER_ITEMS OI ON OI.ORDER_ID=O.ORDER_ID
JOIN PRODUCTS P ON P.PRODUCT_ID=OI.PRODUCT_ID
WHERE  O.STATUS='Delivered'
GROUP BY 1,2
)
SELECT 
	MONTH,
	REVENUE,
	ORDER_COUNT,
	UNIQUE_CUSTOMER,
	ROUND(REVENUE::NUMERIC/NULLIF(ORDER_COUNT,0),2) AS AVG_ORD_VAL,
	ROUND(REVENUE::NUMERIC/NULLIF(UNIQUE_CUSTOMER,0),2) AS revenue_per_customer,
	LAG(REVENUE) OVER(ORDER BY MON_ST) AS PRV_MON_REVENUE,
	ROUND((REVENUE-LAG(REVENUE) OVER(ORDER BY MON_ST))::NUMERIC/ NULLIF(LAG(REVENUE) OVER(ORDER BY MON_ST),0)*100,2) AS mom_change_pct,
	CASE 
		WHEN LAG(REVENUE) OVER(ORDER BY MON_ST) IS NULL THEN '➡️ First'
		WHEN LAG(REVENUE) OVER(ORDER BY MON_ST)<REVENUE THEN '📈 Up'
		ELSE '📉 Down'
		END AS FLAG,
	SUM(REVENUE) OVER (ORDER BY MON_ST) AS RUNNING_TOTAL,
	ROUND(REVENUE::NUMERIC/NULLIF((SELECT SUM(REVENUE) FROM MONTHLY_DATA),0)*100,2) AS pct_of_total,
	ROUND(SUM(REVENUE) OVER (ORDER BY MON_ST)::NUMERIC/NULLIF((SELECT SUM(REVENUE) FROM MONTHLY_DATA),0)*100,2) AS cumulative_pct,
	FIRST_VALUE(REVENUE) OVER(ORDER BY MON_ST) AS baseline,
	ROUND((REVENUE-FIRST_VALUE(REVENUE) OVER(ORDER BY MON_ST))::NUMERIC/NULLIF(FIRST_VALUE(REVENUE) OVER(ORDER BY MON_ST),0)*100,2) AS growth_from_start
FROM MONTHLY_DATA MD
ORDER BY MON_ST


/*"Find customer PAIRS who ordered the SAME product in the SAME month. For each pair, show: customer1, customer2, product, month, 
and both customers' total spending (to see if they're similar value customers)."
Self JOIN approach: match orders by product_id + same month (DATE_TRUNC). Add each customer's total delivered revenue using a CTE or subquery.
No duplicate pairs (c1 < c2).*/


WITH T_SPENDING AS (
SELECT O1.CUSTOMER_ID,  SUM(OI1.QUANTITY*P1.PRICE) AS SPENDS
FROM ORDERS O1
JOIN ORDER_ITEMS OI1 ON O1.ORDER_ID=OI1.ORDER_ID
JOIN PRODUCTS P1 ON P1.PRODUCT_ID=OI1.PRODUCT_ID
WHERE O1.STATUS='Delivered'
GROUP BY 1
)
SELECT DISTINCT
	c1.NAME,
	C2.NAME,
	C1.PRODUCT_NAME,
	C1.MONTH,
	C1.MON_ST,
	TS.SPENDS,
	TS2.SPENDS
FROM (
		SELECT C.NAME, O.CUSTOMER_ID, P.PRODUCT_ID,P.PRODUCT_NAME, DATE_TRUNC('MONTH', O.ORDER_DATE) AS MON_ST, TO_CHAR(O.ORDER_DATE,'MON YYYY') AS MONTH
		FROM ORDERS O 
		JOIN CUSTOMERS C ON C.CUSTOMER_ID=O.CUSTOMER_ID
		JOIN ORDER_ITEMS OI ON O.ORDER_ID=OI.ORDER_ID
		JOIN PRODUCTS P ON P.PRODUCT_ID=OI.PRODUCT_ID
		WHERE O.STATUS='Delivered'
) C1
JOIN (
		SELECT C.NAME, O.CUSTOMER_ID, P.PRODUCT_ID,P.PRODUCT_NAME, DATE_TRUNC('MONTH', O.ORDER_DATE) AS MON_ST
		FROM ORDERS O 
		JOIN CUSTOMERS C ON C.CUSTOMER_ID=O.CUSTOMER_ID
		JOIN ORDER_ITEMS OI ON O.ORDER_ID=OI.ORDER_ID
		JOIN PRODUCTS P ON P.PRODUCT_ID=OI.PRODUCT_ID
		WHERE O.STATUS='Delivered'
) AS C2
		ON C1.MON_ST=C2.MON_ST
		AND
		C1.PRODUCT_ID=C2.PRODUCT_ID
		AND 
		C1.CUSTOMER_ID<C2.CUSTOMER_ID
JOIN T_SPENDING TS ON TS.CUSTOMER_ID=C1.CUSTOMER_ID
JOIN T_SPENDING TS2 ON TS2.CUSTOMER_ID=C2.CUSTOMER_ID
ORDER BY C1.MON_ST


/*💬 Priya:
"Three questions in one go:"

A) Which product categories are bought by Mumbai customers but NOT by Bangalore customers? (EXCEPT)
B) Which customers have BOTH delivered AND cancelled orders? (INTERSECT)
C) Create a unified activity timeline: all delivered orders labeled 'Sale' + all cancelled orders labeled 'Lost Sale'. Sort by date. (UNION ALL)
Three separate queries. Each uses a different set operation.*/
--A
SELECT 
	P.PRODUCT_NAME,
	P.CATEGORY,
	C.CITY
FROM CUSTOMERS C
JOIN ORDERS O ON O.CUSTOMER_ID=C.CUSTOMER_ID AND O.STATUS='Delivered'
JOIN ORDER_ITEMS oi ON OI.ORDER_ID=O.ORDER_ID
JOIN PRODUCTS P on P.PRODUCT_ID=OI.PRODUCT_ID
WHERE C.CITY='Mumbai'
EXCEPT
SELECT 
	P.PRODUCT_NAME,
	P.CATEGORY,
	C.CITY
FROM CUSTOMERS C
JOIN ORDERS O ON O.CUSTOMER_ID=C.CUSTOMER_ID AND O.STATUS='Delivered'
JOIN ORDER_ITEMS oi ON OI.ORDER_ID=O.ORDER_ID
JOIN PRODUCTS P on P.PRODUCT_ID=OI.PRODUCT_ID
WHERE C.CITY='Bangalore'

--B
SELECT 
	C.NAME,
	C.CITY,
	O.STATUS
FROM CUSTOMERS C
JOIN ORDERS O ON C.CUSTOMER_ID=O.CUSTOMER_ID
WHERE O.STATUS='Delivered'
INTERSECT
SELECT 
	C.NAME,
	C.CITY,
	O.STATUS
FROM CUSTOMERS C
JOIN ORDERS O ON C.CUSTOMER_ID=O.CUSTOMER_ID
WHERE O.STATUS='Cancelled'

--C
SELECT 
	C.NAME,
	C.CITY,
	P.PRODUCT_NAME,
	O.ORDER_DATE,
	'SALE' AS ACTIVITY_TYPE
FROM CUSTOMERS C
JOIN ORDERS O ON O.CUSTOMER_ID=C.CUSTOMER_ID AND O.STATUS='Delivered'
JOIN ORDER_ITEMS oi ON OI.ORDER_ID=O.ORDER_ID
JOIN PRODUCTS P on P.PRODUCT_ID=OI.PRODUCT_ID
UNION ALL
SELECT 
	C.NAME,
	C.CITY,
	P.PRODUCT_NAME,
	O.ORDER_DATE,
	'LOST SALE' AS ACTIVITY_TYPE
FROM CUSTOMERS C
JOIN ORDERS O ON O.CUSTOMER_ID=C.CUSTOMER_ID AND O.STATUS='Cancelled'
JOIN ORDER_ITEMS oi ON OI.ORDER_ID=O.ORDER_ID
JOIN PRODUCTS P on P.PRODUCT_ID=OI.PRODUCT_ID
ORDER BY 4


/*💬 Priya:
"ONE query. A complete data audit dashboard showing:"

1. total_customers / active / inactive
2. total_orders / delivered / cancelled / shipped / orphan_orders
3. total_revenue (delivered only)
4. employees_with_data_issues (name or dept needed cleaning)
5. potential_duplicate_orders (same customer + same day)
6. data_quality_score (% of employees with clean data)
Single-row KPI dashboard. ALL metrics as subqueries in ONE SELECT statement.*/

SELECT 
	(SELECT COUNT(*) FROM CUSTOMERS) AS TOTAL_CUSTOMERS,
	(SELECT COUNT(DISTINCT CUSTOMER_ID) FROM ORDERS
		WHERE STATUS='Delivered') AS active,
	(SELECT COUNT(DISTINCT CUSTOMER_ID) FROM CUSTOMERS C
		WHERE NOT EXISTS (SELECT 1 FROM ORDERS O WHERE O.CUSTOMER_ID=C.CUSTOMER_ID)) AS INACTIVE,
	(SELECT COUNT(*) FROM ORDERS ) AS total_orders,
	(SELECT SUM(CASE WHEN O.STATUS='Delivered' THEN 1 ELSE 0 END) FROM ORDERS O) AS DELIVERED,
	(SELECT SUM(CASE WHEN O.STATUS='Cancelled' THEN 1 ELSE 0 END) FROM ORDERS O) AS CANCELLED,
	(SELECT SUM(CASE WHEN O.STATUS='Shipped' THEN 1 ELSE 0 END)FROM ORDERS O) AS SHIPPED,
	(SELECT COUNT(*) FROM ORDERS O
		WHERE NOT EXISTS (SELECT 1 FROM ORDER_ITEMS OI WHERE O.ORDER_ID=OI.ORDER_ID)),
	(SELECT SUM(OI.QUANTITY*P.PRICE) FROM ORDERS O
		JOIN ORDER_ITEMS OI ON O.ORDER_ID=OI.ORDER_ID
		JOIN PRODUCTS P ON P.PRODUCT_ID=OI.PRODUCT_ID
		WHERE O.STATUS='Delivered') as REVENUE,
	(SELECT COUNT(*) FROM EMPLOYEES E 
			WHERE E.DEPARTMENT!=UPPER(TRIM(E.DEPARTMENT)) 
			OR
			E.FULL_NAME!=INITCAP(TRIM(E.FULL_NAME))) AS employees_with_data_issues,
	(SELECT
		COUNT(*) FROM (SELECT CUSTOMER_ID, ORDER_DATE 
						FROM ORDERS 
						GROUP BY 1,2 HAVING COUNT(*)>1)T) AS potential_duplicate_orders,
	 (SELECT ROUND(
    COUNT(*) FILTER(
        WHERE FULL_NAME  = INITCAP(TRIM(FULL_NAME))
        AND   DEPARTMENT = UPPER(TRIM(DEPARTMENT))
    )::NUMERIC
    / NULLIF(COUNT(*), 0) * 100
, 2)
FROM EMPLOYEES) AS DATA_QUALITY_PCT


/*💬 CEO:
"Aditya, show me EVERYTHING about our customers. One query. If this is good, you're getting promoted."
For EVERY customer (even those with no orders):

1. customer_code — 'CUST-001' format (LPAD)
2. name (cleaned)
3. city
4. tenure_months (AGE with BOTH extracts)
5. tenure_label — Veteran/Regular/Newbie
6. delivered_orders (SUM+CASE, 0 if none)
7. cancelled_orders (SUM+CASE)
8. delivered_revenue (SUM+CASE with price, 0 if none)
9. avg_order_value (::NUMERIC + NULLIF)
10. revenue_share_pct (vs company total — subquery, NOT self/self!)
11. spending_rank (DENSE_RANK overall)
12. spending_quartile (NTILE(4))
13. city_rank (DENSE_RANK within city — COALESCE in ORDER BY!)
14. tier — Platinum/Gold/Silver/Bronze (all 4!)
15. category_count (correlated subquery — how many distinct categories)
16. has_electronics — Yes/No (EXISTS with JOINs inside)
17. first_order_date (MIN)
18. days_since_last_order (CURRENT_DATE - MAX, COALESCE for no orders)
19. churn_risk — 'High' if >90 days since last order or no orders, 'Medium' if >60, 'Low' otherwise*/

WITH CD AS(
SELECT 
	C.CUSTOMER_ID, C.NAME, C.CITY, C.SIGNUP_DATE, COUNT(O.ORDER_ID) AS ORD_COUNT,
	SUM(CASE WHEN O.STATUS='Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
	SUM(CASE WHEN O.STATUS='Cancelled' THEN 1 ELSE 0 END) AS  cancelled_orders,
	SUM(CASE WHEN O.STATUS='Delivered' THEN (OI.QUANTITY*P.PRICE) ELSE 0 END)	AS delivered_revenue,
	MIN(O.ORDER_DATE) AS FIRST_ORDER,
	MAX(O.ORDER_DATE) AS LATEST_ORDER
FROM CUSTOMERS C
JOIN ORDERS O ON O.CUSTOMER_ID=C.CUSTOMER_ID
JOIN ORDER_ITEMS OI ON O.ORDER_ID=OI.ORDER_ID
JOIN PRODUCTS P ON P.PRODUCT_ID=OI.PRODUCT_ID
GROUP BY 1,2,3,4
)
SELECT
	'CUST-'||LPAD(CUSTOMER_ID::TEXT,3,'0') AS customer_code,
	NAME,CITY,
	(EXTRACT(YEAR FROM AGE(SIGNUP_DATE))*12 + EXTRACT(MONTH FROM AGE(SIGNUP_DATE))) AS tenure_months,
	CASE 
		WHEN (EXTRACT(YEAR FROM AGE(SIGNUP_DATE))*12 + EXTRACT(MONTH FROM AGE(SIGNUP_DATE)))>=15 THEN 'Veteran'
		WHEN (EXTRACT(YEAR FROM AGE(SIGNUP_DATE))*12 + EXTRACT(MONTH FROM AGE(SIGNUP_DATE)))>=10 THEN 'Regular'
		ELSE 'Newbie' END AS tenure_label,
	delivered_orders,
	cancelled_orders,
	delivered_revenue,
	COALESCE(ROUND(delivered_revenue::NUMERIC/ NULLIF(delivered_orders,0),2),0) AS AVG_ORD_VAL,
	COALESCE(ROUND(delivered_revenue::NUMERIC/NULLIF((SELECT SUM(delivered_revenue) FROM CD),0)*100,2),0) AS revenue_share_pct,
	DENSE_RANK() OVER(ORDER BY delivered_revenue DESC )	AS spending_rank,
	NTILE(4) OVER(ORDER BY delivered_revenue DESC) AS QUARTILE,
	DENSE_RANK() OVER(PARTITION BY CITY ORDER BY COALESCE(delivered_revenue,0) DESC) AS CITY_RNK,
	CASE 
		WHEN delivered_revenue>30000 THEN 'Platinum'
		WHEN delivered_revenue>10000 THEN 'Gold'
		WHEN delivered_revenue>5000 THEN 'Silver'
		ELSE 'Bronze' END AS TIER,
	(SELECT COUNT(DISTINCT p2.category)
        FROM orders o2
        JOIN order_items oi2 ON o2.order_id=oi2.order_id
        JOIN products p2 ON oi2.product_id=p2.product_id
        WHERE o2.customer_id=cd.customer_id
        AND o2.status='Delivered') AS cat_count,
	CASE WHEN EXISTS (SELECT 1 FROM ORDERS O3
						JOIN ORDER_ITEMS OI3 ON OI3.ORDER_ID=O3.ORDER_ID
						JOIN PRODUCTS P3 ON P3.PRODUCT_ID=OI3.PRODUCT_ID
						WHERE o3.customer_id=cd.customer_id AND
						P3.CATEGORY='Electronics')
					THEN 'YES' ELSE 'NO' END  AS HAS_ELECTRONICS,
		FIRST_ORDER,
		(CURRENT_DATE-LATEST_ORDER) AS days_since_last_order,
	 CASE
        WHEN LATEST_ORDER IS NULL THEN 'High'
        WHEN CURRENT_DATE-LATEST_ORDER>90 THEN 'High'
        WHEN CURRENT_DATE-LATEST_ORDER>60 THEN 'Medium'
        ELSE 'Low' END AS churn_risk
FROM CD CD




/*-------------------------------------------------------------------------------------------------------------------------------------------
					PRACTICE REEEEEEEEEEEEEE PRACTICEEEEEEE......!!!!
------------------------------------------------------------------------------------------------------------------------------------------------*/


















































