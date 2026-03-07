select * from fact_orders limit 10;
select * from dim_customers;
select * from dim_locations;
select * from dim_products;
SELECT 
    f.order_id, 
    c.customer_name, 
    p.product_name, 
    l.country, 
    f.sales
FROM fact_orders f
JOIN dim_customers c ON f.customer_id = c.customer_id
JOIN dim_products p ON f.unique_product_id = p.unique_product_id
JOIN dim_locations l ON f.location_id = l.location_id
LIMIT 10;
--KPI 1(Revenue & Profit trends):-The buisness exapnding or shirking Month over Month?
SELECT 
    order_month,
    order_year,
    ROUND(SUM(sales)::numeric, 2) AS monthly_sales,
    ROUND(SUM(profit)::numeric, 2) AS monthly_profit,
    ROUND(LAG(SUM(sales)) OVER (ORDER BY order_year, order_month)::numeric, 2) AS prev_month_sales,
    -- Rounding the percentage calculation
    ROUND(
        ((SUM(sales) - LAG(SUM(sales)) OVER (ORDER BY order_year, order_month)) / 
        NULLIF(LAG(SUM(sales)) OVER (ORDER BY order_year, order_month), 0) * 100)::numeric, 
    2) AS mom_growth_pct
FROM fact_orders
GROUP BY order_year, order_month
ORDER BY order_year asc, order_month asc ;
--KPI 2 The "Pareto" Products (Top 20% of Revenue){top 20% products which generates 80% of company revenue it is also known as 80/20 rule}
--Find which products drive the majority of our sales.Buisness owners use this to priotize  inventory.
select 
	 p.product_name,
	 p.category,
	 round(sum(f.sales)::numeric,2) as total_revenue,
	 round(sum(f.profit)::numeric,2) as total_profit
from fact_orders f
join dim_products p
on f.unique_product_id=p.unique_product_id
group by p.product_name,p.category
order by total_revenue desc
limit 10;
--KPI 3 customer Loyalty Analysis
--Identify those customers who orders frequently and bring in high profits(WHALE customers).
select 
	c.customer_name,
	c.segment,
	count(f.order_id) as total_orders,
	round(sum(f.sales)::numeric,2) as lifetime_value,
	round(avg(profit_margin)::numeric,2) as avg_margin
from fact_orders f
join dim_customers c
on f.customer_id=c.customer_id
group by c.customer_name,c.segment
having count(f.order_id)>5
order by lifetime_value desc
limit 10;
--KPI 4 Shipping speed vs. Profitability
--Does faster shipping lead to lower profits?We check if 'critical' shipping costs  are eating ur margins?
select 
	shipping_efficiency,
	round(avg(shipping_cost)::numeric,2) as avg_shipping_cost,
	round(avg(profit_margin)::numeric,2) as avg_profit_margin,
	count(*) as total_orders
from fact_orders
group by shipping_efficiency
order by avg_profit_margin desc;
--KPI 5 Regional "Bleeding" Points
--which countries or cities are actually losing money(Negative Profit)
select 
	l.country,
	l.market,
	round(sum(f.sales)::numeric,2) as total_sales,
	round(sum(f.profit)::numeric,2) as net_profit
from fact_orders f
join dim_locations l
on f.location_id=l.location_id
group by l.country,l.market
having sum(f.profit)<0 
order by net_profit asc;
--KPI 6 Sub-Category Performance Deep Dive
--Analyse which sub-categories are the most efficient
select
	p.category,
	p.sub_category,
	round(sum(f.sales)::numeric,2) as total_sales,
	round(sum(f.profit)::numeric,2) as total_profit,
	round((sum(f.profit)/sum(f.sales))::numeric,2)*100 as category_profit_pct
from fact_orders f
join dim_products p
on f.unique_product_id=p.unique_product_id
group by p.category,p.sub_category
order by category_profit_pct desc;
--KPI 7 Day-Of-Week Sale Pattern
--Should we increase warehouse staff on Mondays or Fridays?
select 
	order_day_of_week,
	count(order_id) as total_orders,
	round(sum(sales)::numeric,2) as total_sales
from fact_orders
group by order_day_of_week
order by total_sales desc;
--KPI 8 High Discount Impact Analysis
--Does high discount actually result in more quantity sold,or just less profit
select 
	case 
		when discount=0 then 'No Discount'
		when discount<=0.2 then 'Low (0-20%)'
		else 'High (>20%)'
	end as discount_tier,
	round(avg(quantity)::numeric,2) as avg_quantity_per_order,
	round(sum(profit)::numeric,2) as total_profit
from fact_orders
group by 1;
--KPI 9 Customer Segmentation(RFM value){Recency(Last Purchase) Frequency(How often they Buy) Monetary value(amount spent)}
--Find customers who spend the most but also check their avg profit?
with customer_stats as(
	select
		customer_id,
		round(sum(sales)::numeric,2) as total_spent,
		round(sum(profit)::numeric,2) as total_profit,
		count(order_id) as order_count,
		max(order_date) as last_purchase_date
from fact_orders
group by customer_id
)
select * 
from customer_stats
where total_spent>30000
order by total_profit desc;
--KPI 10 Shipping efficiency by Region
--which regions are struggling to ship on time?
select 
	l.region,
	round(avg(f.shipping_days)::numeric,2) as avg_ship_time,
	max(f.shipping_days) as slowest_ship_time
from fact_orders f
join dim_locations l
on f.location_id=l.location_id
group by l.region
order by avg_ship_time desc;
--KPI 11 Product "Deadstock" Analysis
--Stop stocking those products who have low sales but high discount?
select 
	p.product_name,
	round(sum(f.sales)::numeric,2) as total_sale,
	round(avg(f.discount)::numeric,2) as avg_discount
from fact_orders f
join dim_products p
on f.unique_product_id=p.unique_product_id
group by p.product_name
having sum(f.sales)<100 and avg(f.discount)<0.2;

