----------------------------------------------------------
-- Data Exploration and Data Cleansing
SELECT 
*
FROM bronze.crm_prd_info;
-- Check for multiple primary key
-- Expectation: No results
SELECT 
prd_id, 
count(*) 
FROM bronze.crm_prd_info
group by prd_id
having count(*) > 1

-- Check if primary still has multiple values
SELECT *
FROM (
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date) as rn
    FROM bronze.crm_cust_info
) a where rn = 1

--------------------------------------------------------

-- Loading the transformed data from bronze layer to silver layer

INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
prd_id,
REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id, -- Extract Category ID
SUBSTRING(prd_key, 7, LEN(prd_key)) as prd_key, -- Extract product key
prd_nm,
iSNULL(prd_cost,0) as prd_cost, -- Replace NULL values with 0
CASE UPPER(TRIM(prd_line))
     WHEN 'M' THEN 'Mountain'
     WHEN 'R' THEN 'Road'
     WHEN 'S' THEN 'Other Sales'
     WHEN 'T' THEN 'Touring'
     ELSE 'n/a'
END AS prd_line, -- Map product line codes to descriptive values
CAST(prd_start_dt AS DATE) AS prd_start_dt,
CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt -- Calculate the end date as one day before the nest start date
FROM bronze.crm_prd_info

------------------------------------------

-- Post Ingestion Validation changes in the silver layer
-- crm_prd_info table
SELECT 
*
FROM silver.crm_prd_info;
-- Check for multiple primary key
-- Expectation: No results
SELECT 
prd_id, 
count(*) 
FROM silver.crm_prd_info
group by prd_id
having count(*) > 1

-- Check for Unwated spaces
-- Expectation: No results
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- Check for NULL or Negative Numbers
-- Expectation: No results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL 

-- Data Standardization & Consistency
SELECT DISTINCT prd_line
FROM silver.crm_prd_info;

-- Check for Invalid Date Orders
SELECT * 
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

--------------------------------------------------------------------

-- Post Ingestion Validation changes in the silver layer
-- crm_prd_info table

INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price

)
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END AS sls_order_dt,

CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END AS sls_ship_dt,

CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END AS sls_due_dt,

CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantiy * ABS(sls_price) 
        THEN sls_quantiy * ABS(sls_price)
     ELSE sls_sales
END AS sls_sales,

sls_quantiy,

CASE WHEN sls_price IS NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantiy,0)
     ELSE sls_price
END sls_price 

FROM bronze.crm_sales_details

-----------------------------
-- Check for Invalid dates

SELECT sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0
OR LEN(sls_ship_dt) != 8
OR sls_ship_dt > 20500001
OR sls_ship_dt < 19000101

-- Check for Invalid Date Orders
-- Order date should be less than the Shipping date and Due date
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt 

-- Check Data Consistency: Between Sales, Quantity and Price
-- Sales = Quantity * Price
-- Values must not be NULL, Zero or Negative 

SELECT
sls_sales,
sls_quantiy,
sls_price,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantiy * ABS(sls_price) 
        THEN sls_quantiy * ABS(sls_price)
     ELSE sls_sales
END AS sls_sales,

CASE WHEN sls_price IS NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantiy,0)
     ELSE sls_price
END sls_price 
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantiy * sls_price
OR sls_sales IS NULL OR sls_quantiy IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantiy <= 0 OR sls_price <= 0

-----------------------------------------------

-- Validating all the data in silver layer

SELECT * FROM silver.crm_sales_details; 

-- Sales = Quantity * Price
-- Values must not be NULL, Zero or Negative 
SELECT
sls_sales,
sls_quantity,
sls_price,
sls_sales,
sls_price 
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0

/*==========================================================================*/
-- Data Cleaning of bronze.erp_cust_az12 table 
/*==========================================================================*/

SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4, LEN(cid))
     ELSE cid
END AS cid,
CASE WHEN bdate > GETDATE() THEN NULL
     ELSE bdate
END as bdate,
CASE WHEN UPPER(TRIM(gen)) IN ('F','Female') THEN 'Female'
     WHEN UPPER(TRIM(gen)) IN ('M','Male') THEN 'Male'
     ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12


-------------------------------------------
-- Check if the transformation in cid is effective and complete
-- Expectation: Should be no results

SELECT
-- cid,
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4, LEN(cid))
     ELSE cid
END AS cid,
bdate,
gen
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4, LEN(cid))
     ELSE cid
END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)

------------------------------------------------
-- Check Out-of-range Dates in Birthday
-- Check for extrmely old birthdate and birthdate > doday's date
SELECT
bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()

-------------------------------------------------
-- Check all possible values for gender column
-- The gen column has carriage return and can not be cleaned here. 
-- We updated the gen in the bronze layer after the bulk insert by updating the gen column

SELECT
gen,
CASE WHEN UPPER(TRIM(gen)) IN ('F','Female') THEN 'Female'
     WHEN UPPER(TRIM(gen)) IN ('M','Male') THEN 'Male'
     ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12

-------------------------------------------------------------------

-- INSERT the cleaned data in the silver Layer

INSERT INTO silver.erp_cust_az12 (
    cid,
    bdate,
    gen

)
SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid,4, LEN(cid)) -- Removed 'NAS' prefix if present
     ELSE cid
END AS cid,
CASE WHEN bdate > GETDATE() THEN NULL
     ELSE bdate
END as bdate, -- Set future birthdates to NULL
CASE WHEN UPPER(TRIM(gen)) IN ('F','Female') THEN 'Female'
     WHEN UPPER(TRIM(gen)) IN ('M','Male') THEN 'Male'
     ELSE 'n/a'
END AS gen -- Standardize gender values and handle unknown cases
FROM bronze.erp_cust_az12

-- Check for Data Quality in the silver layer

-- Check Out-of-range Dates in Birthday
-- Check for extrmely old birthdate and birthdate > doday's date
-- We did not remove or transform the old brithdates
SELECT
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()
--------------------------------------
--Check for the possible genders
SELECT DISTINCT
gen
FROM silver.erp_cust_az12

--------------------------------------
--Check the final table in the silver layer

Select * from silver.erp_cust_az12

/*==================================================*/
-- CLEAN AND LOAD SILVER LAYER of Table: erp_loc_a101
/*==================================================*/

-- We are joining the silver.erp_loc_a101 with silver.crm_cust_info on cid, cst_key
-- Check if the cid and cst_key have the same values.

-- Clean the cid column (AW-00011000) to match with cst_key (AW00011000)
SELECT TOP(10)cid FROM bronze.erp_loc_a101; 

SELECT TOP(10)cst_key FROM silver.crm_cust_info;

-- Remove the '-' in cid column

SELECT
cid,
REPLACE(cid, '-','') as n_cid
FROM bronze.erp_loc_a101;

-------------------------
-- Check if the cid and cst_key have the same values
-- Expectation: No Results

SELECT
REPLACE(cid, '-','') as cid,
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
     WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
     WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
     ELSE TRIM(cntry)
END as cntry
FROM bronze.erp_loc_a101
WHERE REPLACE(cid, '-','') NOT IN (SELECT cst_key FROM silver.crm_cust_info)

-------------------------------------------

-- Data Standardization & Consistency
-- Check for possible values in cntry column

SELECt DISTINCT cntry FROM bronze.erp_loc_a101
order by cntry;
------------------

-- Standardize the cntry column by handling possible values for each country and getting the NULL and empty string

SELECT DISTINCT
cntry as old_cntry,
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
     WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
     WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
     ELSE TRIM(cntry)
END as cntry
FROM bronze.erp_loc_a101
order by cntry

-----------------------
-- Loading the transformed data from bronze layer to silver layer

INSERT INTO silver.erp_loc_a101 (cid, cntry)
SELECT
REPLACE(cid, '-','') as cid, -- Removed the '-' in the cid column
CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
     WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
     WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
     ELSE TRIM(cntry)
END as cntry -- Standardize and handle missing or blank country values
FROM bronze.erp_loc_a101

-- Check the inserted data

select * from silver.erp_loc_a101

select distinct cntry from silver.erp_loc_a101

/*==================================================*/
-- CLEAN AND LOAD SILVER LAYER of Table: erp_px_cat_g1v2
/*==================================================*/

SELECT 
id,
cat,
subcat,
maintenance
FROM bronze.erp_px_cat_g1v2;

-- Check for unwanter spaces in cat column

SELECT * FROM bronze.erp_px_cat_g1v2
where cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance)

-- Check for Data Standardization and Consistency

SELECt DISTINCT subcat FROM bronze.erp_px_cat_g1v2

--------------------------------

-- Loading the data from bronze to silver layer

INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
SELECT * FROM bronze.erp_px_cat_g1v2

---------------------------------
--Check for data in silver layer

SELECT * FROM silver.erp_px_cat_g1v2

