/*
=================================================================
Create a database and schemas
=================================================================
Script purpose:
  This script creates a new database named Datawarehouse after checking whether the database already exists. If the database exists, it is dropped and recreated. 
  Additionally, the script set up three other schemas, namely: bronze, silver, and gold

WARNING:
    Running this script might drop the entire 'Datawarehouse' database if it exists. All data in the database will be permanently deleted. Proceed with caution and ensure 
    you have proper backup before running this script

*/

-- Create Database
Create database Datawarehouse;

-- Create schema for bronze, silver, and gold
Create schema datawarehouse_bronze;
Create schema datawarehouse_silver;
Create schema datawarehouse_gold;
