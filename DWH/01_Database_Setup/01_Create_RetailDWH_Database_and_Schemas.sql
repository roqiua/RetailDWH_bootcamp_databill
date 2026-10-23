/*
===============================================================================
RETAILDWH DATABASE AND SCHEMA SETUP
===============================================================================
*/
-- Create the RetailDWH database to store the data warehouse objects.
CREATE DATABASE RetailDWH;


GO
-- Switch the current database context to RetailDWH.
USE RetailDWH;


GO
-- Create the staging schema to store extracted source data before transformation.
CREATE SCHEMA stg;


GO
-- Create the dimension schema to store descriptive business entities,
-- such as customers, products, stores, and dates.
CREATE SCHEMA dim;


GO
-- Create the fact schema to store business events and measurable metrics,
-- such as sales transactions and quantities.
CREATE SCHEMA fact;


GO