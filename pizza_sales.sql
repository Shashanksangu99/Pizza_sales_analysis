--creating pizzasales database
create DATABASE pizza_sales;

--creating orders table schema
create table orders(
order_id int not null,
order_date date not null,
order_time time not null,
primary key (order_id));

select * from orders;

--creating order_details schema
create table order_details(
order_detail_id int not null,
order_id int not null,
pizza_id varchar(50) not null,
quantity int not null,
primary key (order_detail_id));


select * from order_details;

--creating pizzas table schema
create table pizzas(
pizza_id varchar(50) not null,
pizza_type_id varchar(50) not null,
pizza_size varchar(10) not null,
price int not null
primary key (pizza_id));

select * from pizzas;

--creating pizza_types table schema
create table pizza_types(
pizza_type_id varchar(50) not null,
pizza_name varchar(50) not null,
category varchar(50) not null,
ingredients varchar(max) not null
primary key (pizza_type_id));

select * from pizza_types;


--Creating a new column time_of_day in orders table
select order_time,
(case when `order_time` between "08:00:00" and "12:00:00" then "Morning"
when `order_time` between "12:01:00" and "16:00:00" then "Afternoon"
when `order_time` between "16:01:00" and "19:00:00" then "Evening"
else "Night"
end) as Time_of_day
from orders;

alter table orders add column time_of_day varchar(20);

update orders set time_of_day = (case when `order_time` between "08:00:00" and "12:00:00" then "Morning"
when `order_time` between "12:01:00" and "16:00:00" then "Afternoon"
when `order_time` between "16:01:00" and "19:00:00" then "Evening"
else "Night"
end);

select * from orders;

--Adding a new column month_name in orders column
alter table orders add column month_name varchar(20) not null;
update orders set month_name = (monthname(orders.order_date));

select * from orders;



--ANALYSIS--
-- -- What is the total number of orders placed
select count(order_id) as Total_orders from orders;

-- Calculate the total revenue generated from pizza sales
WITH Sales_CTE AS (
    SELECT od.quantity, p.price,
           (od.quantity * p.price) AS sales_amount
    FROM order_details as od
    JOIN pizzas as p ON pizzas.pizza_id = order_details.pizza_id
)

SELECT cast(ROUND(SUM(sales_amount), 2) as decimal(10,2)) AS Total_sales
FROM Sales_CTE;


-- Calculate the average order value
WITH Sales_CTE AS (
    SELECT od.quantity, p.price,
           (od.quantity * p.price) AS sales_amount
    FROM order_details AS od
    JOIN pizzas AS p ON p.pizza_id = od.pizza_id
)

SELECT cast(ROUND((SUM(sales_amount) / SUM(quantity)), 2) as decimal(10,2)) AS Avg_order_value
FROM Sales_CTE;


-- Identify the top 5 priced pizza
WITH RankedPizzas AS (
    SELECT pt.name, p.price,
           ROW_NUMBER() OVER (ORDER BY p.price DESC) AS rank
    FROM pizzas AS p
    JOIN pizza_types AS pt ON p.pizza_type_id = pt.pizza_type_id
)

SELECT name, price
FROM RankedPizzas
WHERE rank <= 5;


-- Identify the most common pizza size ordered.
select p.size, sum(od.quantity) as Total_quantity_ordered
from pizzas as p join order_details as od on
p.pizza_id = od.pizza_id
GROUP BY p.size
ORDER BY Total_quantity_ordered DESC;


-- List the top 5 most ordered pizza types along with their quantities.
SELECT pizza_types.name, sum(order_details.quantity) as Total_quantity
from 
pizzas join pizza_types on pizzas.pizza_type_id= pizza_types.pizza_type_id
join order_details on pizzas.pizza_id = order_details.pizza_id
GROUP BY pizza_types.name
ORDER BY Total_quantity DESC
limit 5;


-- Find the total quantity of each pizza category ordered

select pizza_types.category, sum(order_details.quantity) as Total_quantity
from
pizzas join pizza_types on pizzas.pizza_type_id= pizza_types.pizza_type_id
join order_details on pizzas.pizza_id = order_details.pizza_id
GROUP BY pizza_types.category
ORDER BY Total_quantity DESC;

-- Determine the distribution of orders by time of the day.

select orders.time_of_day, count(orders.order_id) as order_count
from orders
group by orders.time_of_day
ORDER BY order_count DESC;

-- Determine the distribution of orders by month.

select orders.month_name, count(orders.order_id) as order_count
from orders
group by orders.month_name
ORDER BY order_count DESC;

-- Find the category-wise distribution of pizzas.

SELECT category, count(pizza_type_id) from pizza_types
group by category;

-- Group the orders by date and calculate the average number of pizzas ordered per day.

WITH DailyOrders AS (
    SELECT 
        DAY(o.order_date) AS Order_day,
        SUM(od.quantity) AS Tot_quantity
    FROM orders AS o
    JOIN order_details AS od ON o.order_id = od.order_id
    GROUP BY o.order_date
),
RankedOrders AS (
    SELECT 
        Order_day,
        AVG(Tot_quantity) OVER (PARTITION BY Order_day) AS avg_order,
        ROW_NUMBER() OVER (ORDER BY AVG(Tot_quantity) OVER (PARTITION BY Order_day) DESC) AS rank
    FROM DailyOrders
)

SELECT Order_day, avg_order
FROM RankedOrders
WHERE rank <= 5
ORDER BY avg_order DESC;



-- Determine the top 3 most ordered pizza types based on revenue

WITH PizzaRevenue AS (
    SELECT 
        pt.name AS pizza_type,
        SUM(p.price * od.quantity) AS Total_rev,
        RANK() OVER (ORDER BY SUM(p.price * od.quantity) DESC) AS revenue_rank
    FROM pizzas AS p
    JOIN order_details AS od ON p.pizza_id = od.pizza_id
    JOIN pizza_types AS pt ON pt.pizza_type_id = p.pizza_type_id
    GROUP BY pt.name
)
SELECT pizza_type, Total_rev
FROM PizzaRevenue
WHERE revenue_rank <= 3
ORDER BY Total_rev DESC;


-- Analyze the cumulative revenue generated over time

SELECT 
    order_date, 
    SUM(Tot_rev) OVER (ORDER BY order_date) AS Cum_ren 
FROM 
(
    SELECT 
        orders.order_date, 
        SUM(pizzas.price * order_details.quantity) AS Tot_rev
    FROM 
        order_details 
        JOIN pizzas ON order_details.pizza_id = pizzas.pizza_id
        JOIN orders ON orders.order_id = order_details.order_id
    GROUP BY 
        orders.order_date
) AS a;


-- Determine the top 3 most ordered pizza types based on revenue for each pizza category.
-- CTE to calculate total revenue for each pizza
WITH RevenueCTE AS (
    SELECT 
        pizza_types.category, 
        pizza_types.name, 
        SUM(pizzas.price * order_details.quantity) AS Tot_rev
    FROM 
        pizza_types
        JOIN pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN order_details ON pizzas.pizza_id = order_details.pizza_id
    GROUP BY 
        pizza_types.category, 
        pizza_types.name
),

-- CTE to rank pizzas within each category based on total revenue
RankedCTE AS (
    SELECT 
        category, 
        name, 
        Tot_rev, 
        RANK() OVER (PARTITION BY category ORDER BY Tot_rev DESC) AS Ranking
    FROM 
        RevenueCTE
)

-- Final query to select top 3 pizzas per category
SELECT *
FROM 
    RankedCTE
WHERE 
    Ranking <= 3;


-- Calculate the percentage contribution of each pizza category to total revenue.

-- CTE to calculate total revenue per category
WITH CategoryRevenue AS (
    SELECT 
        pizza_types.category, 
        SUM(pizzas.price * order_details.quantity) AS Tot_rev
    FROM 
        pizza_types
        JOIN pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN order_details ON pizzas.pizza_id = order_details.pizza_id
    GROUP BY 
        pizza_types.category
),

-- CTE to calculate total sales across all categories
TotalSales AS (
    SELECT 
        ROUND(SUM(order_details.quantity * pizzas.price), 2) AS Total_sales
    FROM 
        pizza_types
        JOIN pizzas ON pizza_types.pizza_type_id = pizzas.pizza_type_id
        JOIN order_details ON pizzas.pizza_id = order_details.pizza_id
),

-- CTE to calculate percentage contribution for each category
PercentageContribution AS (
    SELECT 
        c.category, 
        ROUND((c.Tot_rev / t.Total_sales) * 100, 2) AS percentage_contri
    FROM 
        CategoryRevenue c
        CROSS JOIN TotalSales t
)

-- Final query to select percentage contribution per category
SELECT *
FROM 
    PercentageContribution;
