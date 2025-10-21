# SQL Data Analysis Project

A full **retail sales analytics and reporting project** built entirely with SQL.  
This project demonstrates how to extract, clean, and analyze data to deliver actionable business insights — without relying on external BI tools.

---

## Project Overview
This project simulates a **retail data warehouse** structured using a **star schema**, including:

- `fact_sales` – transactional sales data  
- `dim_products` – product master data  
- `dim_customers` – customer demographics and profile  

Using advanced SQL queries, I analyzed **sales trends, customer segments, and product performance**, creating reusable data views for business intelligence reporting.

---

## Key Achievements
- Built **time-based trend analyses** (yearly, monthly, cumulative) for sales and customer metrics.  
- Designed **running total** and **moving average** queries to monitor performance over time.  
- Developed **customer segmentation logic** (VIP, Regular, New) using lifespan and spending.  
- Created **product performance benchmarking** against category and prior-year averages.  
- Built two **reporting views**:
  - `gold.report_customers` – customer analytics mart  
  - `gold.product_report` – product performance mart  

---

## Insights Generated
- Identified top-performing product categories and underperforming segments.  
- Calculated customer retention and lifetime value (LTV).  
- Analyzed category contribution to overall sales (part-to-whole analysis).  
- Evaluated product lifespan and recency to support inventory decisions.

---

## Tools & Technologies
- **SQL Server (T-SQL)**
- **CTEs & Window Functions**
- **Aggregate & Analytical Functions**
- **Joins, Grouping, and Data Modeling**

---

## Impact
Delivered a set of **ready-to-query SQL views** that serve as data marts for dashboards in tools like **Power BI** or **Tableau**, improving data visibility and decision-making efficiency across sales and marketing teams.

---
