
/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL(Extract, Transform, Load) process to populate
    the 'silver' schema from the 'bronze' schema. 
    It performs the following actions:
    - Truncates the silver tables.
    - Inserts transformed, cleaned data from Bronze into the Silver table.

Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_bronze;
===============================================================================
*/

EXEC silver.load_silver

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE()
		PRINT' =======================================';
		PRINT 'Loading the silver layer';
		PRINT '=======================================';

		PRINT '---------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '---------------------------------------';

		-- Loading silver.crm_cust_info
		SET @start_time = GETDATE()
		PRINT '>> Truncating Table : silver.crm_cust_info';
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> inserting data into silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info(cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr,cst_create_date)
		select 
			cust_id,
			cst_key,
			Trim(cst_firstname) as cst_firstname,
			Trim(cst_lastname) as cst_lastname,
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'n/a'
			END cst_marital_status,
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END cst_gndr,
			cst_create_date
		From
		(
		select
			*,
			ROW_NUMBER() over(partition by cust_id order by cst_create_date desc) as flag_last
		from bronze.crm_cust_info
		where cust_id is not null
		) t
		where flag_last = 1;
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------'



	-- Loading silver.crm_prd_info
	SET @start_time = GETDATE()
	PRINT '>> Truncating Table : silver.crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT '>> inserting data into silver.crm_prd_info';
	INSERT INTO silver.crm_prd_info(
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)
	select
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') as cat_id,
		SUBSTRING(prd_key, 7, LEN(prd_key)) as prd_key,
		prd_nm,
		ISNULL(prd_cost, 0) as prd_cost,
		CASE UPPER(TRIM(prd_line))
			 WHEN 'M' THEN 'Mountain'
			 WHEN 'R' THEN 'Road'
			 WHEN 'S' THEN 'Other Sales'
			 WHEN 'T' THEN 'Touring'
			 ELSE 'n/a'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) ,
		CAST(LEAD(prd_start_dt) OVER (partition by prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt
	from bronze.crm_prd_info;
	SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------'



	-- Silver Data Transformation for sales table
	SET @start_time = GETDATE()
	PRINT '>> Truncating Table : silver.crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;
	PRINT '>> inserting data into silver.crm_sales_details';
	INSERT INTO silver.crm_sales_details(
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
	select
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
		CASE WHEN sls_sales  IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales
		END AS sls_sales,
		sls_quantity,
		CASE WHEN sls_price IS NULL OR sls_price <= 0 THEN sls_sales / NULLIF(sls_quantity, 0)
			 ELSE sls_price
		END sls_price
	from bronze.crm_sales_details;
	SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------'


	SET @start_time = GETDATE()
	PRINT '>> Truncating Table : silver.erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT '>> inserting data into silver.erp_cust_az12';
	-- Silver Data Transformation for erp_cust_az12
	INSERT INTO silver.erp_cust_az12(cid, bdate, gen)
	select 
	CASE WHEN cid like 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
		 ELSE cid
	END cid,
	CASE WHEN bdate > GETDATE() THEN NULL
		 ELSE bdate
	END bdate,
	CASE WHEN UPPER(TRIM (gen)) IN ('F', 'FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM (gen)) IN ('M', 'MALE') THEN 'Male'
		 ELSE 'n/a'
	END as gen
	from bronze.erp_cust_az12;
	SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------'



	SET @start_time = GETDATE()
	PRINT '>> Truncating Table : silver.erp_loc_a101';
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT '>> inserting data into silver.erp_loc_a101';
	-- Silver Data Transformation forerp_loc_a101
	INSERT INTO silver.erp_loc_a101(cid, cntry)
	select 
	REPLACE(cid, '-', '') cid,
	CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		 WHEN TRIM(cntry)  IN ('US', 'USA') THEN 'United States'
		 WHEN TRIM(cntry) = '' OR cntry = NULL THEN 'n/a'
		 ELSE TRIM(cntry)
	END as cntry
	from bronze.erp_loc_a101;
	SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------'


	SET @start_time = GETDATE()
	PRINT '>> Truncating Table : silver.erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT '>> inserting data into silver.erp_px_cat_g1v2';
	-- Silver Data Transformation for [silver].[erp_px_cat_g1v2]
	INSERT INTO silver.erp_px_cat_g1v2
	(id, cat, subcat, maintenance)
	select 
	id,
	cat,
	subcat,
	maintenance
	from bronze.erp_px_cat_g1v2;
	SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second,@start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-----------------';

	SET @batch_end_time = GETDATE();
		PRINT '============================================='
		PRINT ' loading silver Layer is completed';
		PRINT ' - Total Load duration: ' + CAST (DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT '============================================='

	END TRY
	BEGIN CATCH
		PRINT '=========================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT 'ERROR MESSAGE' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR MESSAGE' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================';
	END CATCH

END
