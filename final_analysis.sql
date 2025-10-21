/*========================================
= Time helpers (portable)
========================================*/
-- Month bucket (first day of month)
-- Use this expression wherever we need "by month"
--   DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
---------------------------------------------------------


/*========================================
= 1) Yearly summary
========================================*/
SELECT
  DATEPART(YEAR, order_date)              AS order_year,
  SUM(sales_amount)                       AS total_sales,
  COUNT(DISTINCT customer_key)            AS total_customers,
  SUM(quantity)                           AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEPART(YEAR, order_date)
ORDER BY order_year;


-- 2) Month-of-year summary (aggregated across all years)
SELECT
  DATEPART(MONTH, order_date)             AS month_num,
  DATENAME(MONTH, order_date)             AS month_name,
  SUM(sales_amount)                       AS total_sales,
  COUNT(DISTINCT customer_key)            AS total_customers,
  SUM(quantity)                           AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEPART(MONTH, order_date), DATENAME(MONTH, order_date)
ORDER BY month_num;


-- 3) Year–Month summary (each calendar month)
SELECT
  DATEPART(YEAR,  order_date)                                 AS order_year,
  DATEPART(MONTH, order_date)                                 AS order_month,
  DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)       AS month_start,
  SUM(sales_amount)                                           AS total_sales,
  COUNT(DISTINCT customer_key)                                AS total_customers,
  SUM(quantity)                                               AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY
  DATEPART(YEAR, order_date),
  DATEPART(MONTH, order_date),
  DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY month_start;


-- 4) Orders & customers per month
SELECT
  DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month_start,
  COUNT(DISTINCT order_number)                          AS total_orders_per_month,
  COUNT(DISTINCT customer_key)                          AS total_customers_per_month
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
ORDER BY month_start;


-- 5) Monthly sales + running total over time
WITH monthly AS (
  SELECT
    DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS month_start,
    SUM(sales_amount)                                     AS total_sales
  FROM gold.fact_sales
  WHERE order_date IS NOT NULL
  GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
SELECT
  month_start,
  total_sales,
  SUM(total_sales) OVER (ORDER BY month_start
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_sales
FROM monthly
ORDER BY month_start;


-- 6) Yearly total sales
SELECT
  DATEFROMPARTS(YEAR(order_date), 1, 1) AS year_start,
  SUM(sales_amount)                     AS total_sales_by_year
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(order_date), 1, 1)
ORDER BY year_start;


-- 7) Moving average of PRICE (3-year window; change to taste)
WITH yearly AS (
  SELECT
    DATEFROMPARTS(YEAR(order_date), 1, 1) AS year_start,
    AVG(price)                             AS avg_price
  FROM gold.fact_sales
  WHERE order_date IS NOT NULL
  GROUP BY DATEFROMPARTS(YEAR(order_date), 1, 1)
)
SELECT
  year_start,
  avg_price,
  AVG(avg_price) OVER (ORDER BY year_start
                       ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_price_3y
FROM yearly
ORDER BY year_start;


-- 8) Performance analysis by product & year
WITH year_product_sales AS (
  SELECT
    DATEPART(YEAR, f.order_date) AS order_year,
    d.product_name,
    SUM(f.sales_amount)          AS total_sales_for_year
  FROM gold.fact_sales AS f
  LEFT JOIN gold.dim_products AS d
    ON f.product_key = d.product_key
  WHERE f.order_date IS NOT NULL
  GROUP BY DATEPART(YEAR, f.order_date), d.product_name
)
SELECT
  order_year,
  product_name,
  total_sales_for_year,
  AVG(total_sales_for_year) OVER (PARTITION BY product_name)                            AS avg_sales_for_product,
  total_sales_for_year - AVG(total_sales_for_year) OVER (PARTITION BY product_name)    AS diff_vs_avg,
  CASE
    WHEN total_sales_for_year >  AVG(total_sales_for_year) OVER (PARTITION BY product_name) THEN 'Above Avg'
    WHEN total_sales_for_year <  AVG(total_sales_for_year) OVER (PARTITION BY product_name) THEN 'Below Avg'
    ELSE 'Avg'
  END                                                                                  AS avg_change,
  LAG(total_sales_for_year) OVER (PARTITION BY product_name ORDER BY order_year)       AS prev_year_sales,
  total_sales_for_year - LAG(total_sales_for_year) OVER (PARTITION BY product_name
                                                        ORDER BY order_year)           AS delta_vs_prev,
  CASE
    WHEN total_sales_for_year >  LAG(total_sales_for_year) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Above prev'
    WHEN total_sales_for_year <  LAG(total_sales_for_year) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Below prev'
    ELSE 'Equal to prev'
  END                                                                                  AS prev_change
FROM year_product_sales
ORDER BY product_name, order_year;


-- 9) Part-to-whole: category share of total sales
WITH category_sales AS (
  SELECT
    p.category,
    SUM(f.sales_amount) AS total_sales_amount
  FROM gold.fact_sales AS f
  LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
  GROUP BY p.category
)
SELECT
  category,
  total_sales_amount,
  SUM(total_sales_amount) OVER ()                                                     AS overall_sales,
  CONCAT(ROUND(CAST(total_sales_amount AS FLOAT) / SUM(total_sales_amount) OVER () * 100.0, 2), '%')
                                                                                      AS percentage_of_total
FROM category_sales
ORDER BY total_sales_amount DESC;


-- 10) Product counts by COST ranges + contribution
WITH categorization AS (
  SELECT
    product_key,
    product_name,
    cost,
    CASE
      WHEN cost < 100              THEN 'below 100'
      WHEN cost BETWEEN 100 AND 500  THEN '100-500'
      WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
      ELSE 'above 1000'
    END AS cost_range
  FROM gold.dim_products
),
final_process AS (
  SELECT cost_range, COUNT(product_key) AS total_products
  FROM categorization
  GROUP BY cost_range
)
SELECT
  cost_range,
  total_products,
  SUM(total_products) OVER ()                                                          AS number_of_products,
  CONCAT(ROUND(CAST(total_products AS FLOAT) / CAST(SUM(total_products) OVER () AS FLOAT) * 100.0, 2), '%')
                                                                                       AS products_contribution
FROM final_process
ORDER BY
  CASE cost_range
    WHEN 'below 100' THEN 1
    WHEN '100-500'   THEN 2
    WHEN '500-1000'  THEN 3
    ELSE 4
  END;


-- 11) Customer segmentation by spending & lifespan
WITH customer_spending AS (
  SELECT
    f.customer_key,
    SUM(f.sales_amount)                              AS total_spending,
    MIN(f.order_date)                                AS first_order,
    MAX(f.order_date)                                AS last_order,
    DATEDIFF(MONTH, MIN(f.order_date), MAX(f.order_date)) AS life_span_months
  FROM gold.fact_sales AS f
  GROUP BY f.customer_key
),
labeled AS (
  SELECT
    customer_key,
    CASE
      WHEN life_span_months >= 12 AND total_spending >  5000 THEN 'VIP'
      WHEN life_span_months >= 12 AND total_spending <= 5000 THEN 'Regular'
      ELSE 'New'
    END AS customer_segment
  FROM customer_spending
)
SELECT
  customer_segment,
  COUNT(*) AS total_number_by_segment
FROM labeled
GROUP BY customer_segment
ORDER BY customer_segment;


-- 12) View: gold.report_customers
CREATE OR ALTER VIEW gold.report_customers AS
WITH base_query AS (  -- date preparation
  SELECT
    f.order_number,
    f.product_key,
    f.order_date,
    f.sales_amount,
    f.quantity,
    c.customer_key,
    c.customer_number,
    c.birthdate,
    CONCAT(c.first_name, ' ', c.last_name)          AS customer_name,
    DATEDIFF(YEAR, c.birthdate, GETDATE())          AS age
  FROM gold.fact_sales AS f
  LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
  WHERE f.order_date IS NOT NULL
),
customer_aggregation AS ( -- aggregation
  SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    COUNT(DISTINCT order_number)                     AS total_orders,
    SUM(sales_amount)                                AS total_sales,
    SUM(quantity)                                    AS total_quantity,
    COUNT(DISTINCT product_key)                      AS total_products,
    MAX(order_date)                                  AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months
  FROM base_query
  GROUP BY customer_key, customer_number, customer_name, age
)
SELECT
  customer_key,
  customer_number,
  customer_name,
  age,
  CASE
    WHEN age < 20        THEN 'Under 20'
    WHEN age BETWEEN 20 AND 29 THEN '20-29'
    WHEN age BETWEEN 30 AND 39 THEN '30-39'
    WHEN age BETWEEN 40 AND 49 THEN '40-49'
    ELSE '50 and above'
  END                                                    AS age_group,
  total_orders,
  total_sales,
  total_quantity,
  total_products,
  last_order_date,
  lifespan_months,
  CASE
    WHEN lifespan_months >= 12 AND total_sales >  5000 THEN 'VIP'
    WHEN lifespan_months >= 12 AND total_sales <= 5000 THEN 'Regular'
    ELSE 'New'
  END                                                    AS customer_segment,
  DATEDIFF(MONTH, last_order_date, GETDATE())            AS recency_months,
  CASE WHEN total_orders = 0 THEN 0 ELSE total_sales / NULLIF(total_orders, 0) END AS avg_order_value,
  CASE WHEN lifespan_months = 0 THEN 0 ELSE total_sales / NULLIF(lifespan_months, 0) END AS avg_monthly_spend
FROM customer_aggregation;


-- 13) View: gold.product_report (fixed joins, fields, trailing comma)
CREATE OR ALTER VIEW gold.product_report AS
WITH base_table AS (
  SELECT
    f.customer_key,
    f.order_number,
    f.order_date,
    f.sales_amount,
    f.quantity,
    f.price,
    p.product_name,
    p.category,
    p.subcategory,
    p.cost
  FROM gold.fact_sales AS f
  LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
  WHERE f.order_date IS NOT NULL
)
SELECT
  product_name,
  category,
  subcategory,
  COUNT(DISTINCT order_number)                 AS total_orders,
  SUM(sales_amount)                            AS total_sales,
  SUM(quantity)                                AS total_quantity_sold,
  COUNT(DISTINCT customer_key)                 AS total_customers,
  DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan_months,
  DATEDIFF(MONTH, MAX(order_date), GETDATE())  AS recency_months,
  MAX(order_date)                              AS last_order
FROM base_table
GROUP BY product_name, category, subcategory;
