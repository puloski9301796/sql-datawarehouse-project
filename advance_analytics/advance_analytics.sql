/*===========================================================================================*/
                            -- CHANGES OVER TIME ANALYSIS
/*===========================================================================================*/

-- Analyze Sales Performance Over Time
-- Changes Over Year
SELECT 
YEAR(order_date) as order_year,
SUM(sales_amount) as toal_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date) 
ORDER BY YEAR(order_date) 

-- Changes Over Month
SELECT 
MONTH(order_date) as order_month,
SUM(sales_amount) as toal_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date) 
ORDER BY MONTH(order_date) 

-- Changes Over Month and Year
SELECT 
YEAR(order_date) as order_month,
MONTH(order_date) as order_month,
SUM(sales_amount) as toal_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date) 
ORDER BY YEAR(order_date), MONTH(order_date) 

-- Changes Over Yean and Month
SELECT 
DATETRUNC(month,order_date) as order_date,
SUM(sales_amount) as toal_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
ORDER BY DATETRUNC(month,order_date)

-- Change the format of the order date

SELECT 
FORMAT(order_date, 'yyyy-MMM') as order_date,
SUM(sales_amount) as toal_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')


/*===========================================================================================*/
                            -- CUMULATIVE ANALYSIS
/*===========================================================================================*/
-- Aggregate the data progressively over time

-- Calculate the Total Sales per Month
-- and the running Total Sales over time

SELECT 
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total_sales,
CAST(((SUM(total_sales) OVER(ORDER BY order_date) - total_sales) * 100.0 / NULLIF(total_sales, 0)) AS DECIMAL(10, 2)) AS percentage_increase
FROM (
    SELECT 
    DATETRUNC(month,order_date) as order_date,
    SUM(sales_amount) as total_sales
    -- COUNT(DISTINCT customer_key) as total_customers,
    -- SUM(quantity) as total_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month,order_date)
) t

------

SELECT 
order_date,
total_sales,
SUM(total_sales) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) AS running_total_sales,
CAST(((SUM(total_sales) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) - total_sales) * 100.0 / NULLIF(total_sales, 0)) AS DECIMAL(10, 2)) AS percentage_increase
FROM (
    SELECT 
    DATETRUNC(month,order_date) as order_date,
    SUM(sales_amount) as total_sales
    -- COUNT(DISTINCT customer_key) as total_customers,
    -- SUM(quantity) as total_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month,order_date)
) t

-------

-- Cumulative Running Total Sales by Year

SELECT 
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER(ORDER BY order_date) AS running_averag_price

-- CAST(((SUM(total_sales) OVER(ORDER BY order_date) - total_sales) * 100.0 / NULLIF(total_sales, 0)) AS DECIMAL(10, 2)) AS percentage_increase
FROM (
    SELECT 
    DATETRUNC(year,order_date) as order_date,
    SUM(sales_amount) as total_sales,
    AVG(price) AS avg_price
    -- COUNT(DISTINCT customer_key) as total_customers,
    -- SUM(quantity) as total_quantity
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year,order_date)
) t


/*===========================================================================================*/
                            -- PERFORMANCE ANALYSIS
/*===========================================================================================*/

-- Comaaring current value to target value

-- Analyze the yearly performance of products by comparing each product's sales 
-- to both its average sales performance and the previous year's sales

WITH yearly_product_sales AS (
    SELECT 
    YEAR(s.order_date) AS order_year,
    p.product_name,
    SUM(s.sales_amount) current_sales
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p
        ON s.product_key = p.product_key
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(s.order_date), p.product_name
)
SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER(PARTITION BY product_name) as avg_sales,
current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Avg'
     WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Avg'
     ELSE 'Avg'
END AS avg_change,
-- Year-Over-Year Analysis
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS prev_year_sales,
(current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)) AS salesdiff_prev_year,
CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
     WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
     ELSE 'No change'
END AS prev_year_change
FROM yearly_product_sales
ORDER BY product_name, order_year

/*===========================================================================================*/
                            -- PART-TO-WHOLE ANALYSIS
/*===========================================================================================*/

-- Find out the proportion of a part relative to the whole

-- Analyse how an individual part is performing compared to the overall.
-- Allowing us to understand which category has the greatest impact on the business.

-- FORMULA: (Sales / Total Sales) * 100 by Category
--          (Quantity / Total Quantity) * 100 by Country

-- Which category contribute the most to the overall business sales

WITH category_sales AS (
    SELECT
    category,
    SUM(sales_amount) as total_sales
    FROM gold.fact_sales as s
    LEFT JOIN gold.dim_products as p
        ON s.product_key = p.product_key
    GROUP BY category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER() overall_sales
FROM category_sales

/*===========================================================================================*/
                            -- DATA SEGMENTATION --
/*===========================================================================================*/

-- Segement products into cost ranges and count how many products fall into each segments

WITH product_segment AS (
SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
     WHEN cost BETWEEN 100 and 500 THEN '100-500'
     WHEN cost BETWEEN 500 and 1000 THEN '500-1000'
     ELSE 'Above 1000'
END AS cost_range
FROM gold.dim_products
)
SELECT
cost_range,
COUNT(product_key) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products

-- Group customers into threee segments based on their spending behaviour:
-- - VIP: Customers with atleast 12 months of history and spending more than 5000.
-- - Regular: Customers with atleast 12 months of history by spending 5000 or less.
-- - New: Customers with a lifespan of less than 12 months.
--and find the total number of customers by each group 

WITH customer_spending as (
    SELECT
    b.customer_key,
    SUM(a.sales_amount) as total_spending,
    MIN(a.order_date) as first_order,
    MAX(a.order_date) as last_order,
    DATEDIFF(month, MIN(a.order_date), MAX(a.order_date)) as mob
    FROM gold.fact_sales a
    LEFT JOIN gold.dim_customers b
    ON a.customer_key = b.customer_key
    GROUP BY b.customer_key;
)
select 
    customer_segment,
    COUNT(customer_key) as total_customers
FROM (
    select 
    customer_key,
    CASE WHEN mob >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN mob >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment
    from customer_spending;
) a
GROUP BY customer_segment;


/*===========================================================================================*/
                            -- BUILDING THE CUSTOMER REPORT --
/*===========================================================================================*/

/*
PURPOSE: This report consolidates key customer metric and behaviors

HIGHLIGHTS: 
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and Age groups.
    3. Aggregate customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        -lifespan (in months)
    4. Caluculate valueable KPIs:
        - recent (months since last order)
        - average order value
        - average monthly spend
*/

-- STEPS:

CREATE VIEW gold.report_customers AS 

    WITH base_query as (
        -- 1. Base Query: Retrieves core coumns from tables
        SELECT
            a.order_number,
            a.product_key,
            a.order_date,
            a.sales_amount,
            a.quantity,
            b.customer_key,
            b.customer_number,
            CONCAT(b.first_name, ' ', b.last_name) as customer_name,
            DATEDIFF(year, b.birthdate, GETDATE()) as age
        FROM gold.fact_sales a
        LEFT JOIN gold.dim_customers b
            ON a.customer_key = b.customer_key
        WHERE a.order_date is NOT NULL
    ),

    customer_aggregation as ( 
        -- 3. Aggregate customer-level metrics:
        select
            customer_key,
            customer_number,
            customer_name,
            age,
            COUNT(DISTINCT order_number) as total_orders,
            SUM(sales_amount) as total_sales,
            SUM(quantity) as total_quantity,
            COUNT(DISTINCT product_key) AS total_products,
            MAX(order_date) as last_order_date,
            DATEDIFF(month, MIN(order_date), MAX(order_date)) as lifespan
        from base_query
        GROUP BY 
            customer_key,
            customer_number,
            customer_name,
            age
    )
    -- 2. Segments customers into categories (VIP, Regular, New) and Age groups.
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        CASE WHEN age < 20 THEN 'Under 20'
            WHEN age BETWEEN 20 AND 29 THEN '20-29'
            WHEN age BETWEEN 30 AND 39 THEN '30-39'
            WHEN age BETWEEN 40 AND 49 THEN '40-49'
            ELSE '50 and Above'
        END AS age_group,
        total_orders,
        total_sales,
        total_quantity,
        total_products,
        lifespan,
        CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment,
        last_order_date,
        DATEDIFF(month, last_order_date, GETDATE()) AS recency,
        
        -- Compute Average Order Value (AVO) - FORMULA:  total sales / total number of orders 
        CASE WHEN total_orders = 0 THEN 0
            ELSE total_sales / total_orders
        END AS avg_order_value,
        
        -- Compute average monthly spend - FORMULA: total sales / number of months
        CASE WHEN lifespan = 0 THEN total_sales
            ELSE total_sales / lifespan
        END AS avg_monthly_spend
    FROM customer_aggregation
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age,
        total_orders,
        total_sales,
        total_quantity,
        total_products,
        last_order_date,
        lifespan;


/*===========================================================================================*/
                            -- BUILDING THE PRODUCT REPORT --
/*===========================================================================================*/

/*
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
        - total orders
        - total sales
        - total quantity sold
        - total customers (unique)
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last sale)
        - average order revenue (AOR)
        - average monthly revenue
*/

CREATE VIEW gold.report_products AS 
WITH base_query AS (
    SELECT
        a.order_number,
        a.customer_key,
        a.order_date,
        a.sales_amount,
        b.product_key,
        b.product_number,
        b.product_name,
        a.quantity,
        b.category,
        b.subcategory,
        b.cost
    FROM gold.fact_sales a
    LEFT JOIN gold.dim_products b
        ON a.product_key = b.product_key
    WHERE a.order_date is NOT NULL
),

product_aggregation AS (
    SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) as lifespan,
    MAX(order_date) as last_sales_date,
    COUNT(DISTINCT order_number) as total_orders,
    COUNT(DISTINCT customer_key) AS total_cutomers,
    SUM(sales_amount) as total_sales,
    SUM(quantity) as total_quantity,

    -- Get the Average Selling Price - FORMULA: sales amount / quantity
    ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
    FROM base_query
    GROUP BY
    product_key,
    product_name,
    category,
    subcategory,
    cost
)

/*=================================================================
    3. Final query: Combines all product results into one output
===================================================================*/

SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    lifespan,
    last_sales_date,
    DATEDIFF(month, last_sales_date, GETDATE()) AS recency_in_months,
    CASE WHEN total_sales > 50000 THEN 'High-Performer'
         WHEN total_sales >= 10000 THEN 'Mid-Range'
         ELSE 'Low-Performer'
    END AS product_segment,
    total_orders,
    total_cutomers,
    total_sales,
    total_quantity,
    avg_selling_price,

    -- Average Order Revenue (AOR) - FORMULA: total_sales / total_orders
    CASE WHEN total_orders = 0 THEN 0
         ELSE total_sales / total_orders
    END AS avg_order_revenue,

    -- Average Monthly Revenue (AMR) - FORMULA: otal_sales / lifespan
    CASE WHEN lifespan = 0 THEN total_sales
         ELSE total_sales / lifespan
    END AS avg_monthly_revenue

from product_aggregation





