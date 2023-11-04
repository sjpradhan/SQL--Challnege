select * from members;
select * from menu;
select * from sales;

--1.What is the total amount each customer spent at the restaurant?

select customer_id,sum(price) as total_price
from menu m
join sales s on s.product_id = m.product_id
group by 1
order by customer_id asc;

--2. How many days has each customer visited the restaurant?

SELECT customer_id, count(date_part('day',order_date)) as count_of_days
from sales
group by 1
order by 1;

--3. What was the first item from the menu purchased by each customer?

select customer_id , min(order_date) as first_order
from sales
group by 1
order by 1;

--4. What is the most purchased item on the menu and how many times was 
-- it purchased by each customers?

select *,
sum(purchase_order) over(partition by product_name) as total
from 
(select customer_id,product_name,count(s.product_id) purchase_order
from menu m
join sales s on s.product_id = m.product_id
group by 1,2
) as x
order by 4 desc
limit 3;

--5. Which item was the most popular for each customer?

with cte as
(select customer_id,product_name,count(*) popularity_count
from sales s 
join menu m on m.product_id = s.product_id
group by  1,2),
cte2 as
    (select customer_id,product_name,
        rank() over(partition by customer_id order by popularity_count desc ) as rnk
    from cte)
select customer_id,product_name
from cte2
where rnk = 1;

--6. Which item was purchased first by the customer after they became a member?

with cte as 
    (select customer_id,order_date,product_id
    from 
        (select s.customer_id,order_date,product_id,
            row_number() over(partition by s.customer_id order by order_date) as rnk
        from sales s 
        join members m on m.customer_id = s.customer_id
        where s.order_date >= m.join_date) as x
    where rnk = 1)
select customer_id,product_name,order_date
from cte c
join menu m on c.product_id = m.product_id
order by order_date asc;

--7. Which item was purchased just before the customer became a member?

with cte as
    (select s.customer_id,order_date,product_id,
    row_number() over(partition by s.customer_id order by order_date desc) as rnk
    from sales s
    join members m on s.customer_id = m.customer_id
    where order_date < join_date)
select 
    customer_id,order_date,product_name
from cte c
join menu m on c.product_id = m.product_id
where rnk = 1;

--8. What is the total items and amount spent for each member before they became a member?

select s.customer_id,
    count(s.product_id) total_itmes,
    sum(price) as total_amount_spent
from sales s
left join members m on s.customer_id = m.customer_id
join menu me on s.product_id = me.product_id
where order_date < join_date or m.join_date is null
group by 1
order by customer_id asc;

--9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - 
-- how many points would each customer have?

select s.customer_id,
    sum(case when product_name = 'sushi' then (price * 20)
        else (price * 10)
        end) as points
from sales s
join menu m on m.product_id = s.product_id
group by 1
order by points desc;

/* 10. In the first week after a customer joins the program (including their join date) they 
earn 2x points on all items, not just sushi - how many points do customer A and B have at the 
end of January? */

with cte as 
    (select s.customer_id,join_date,product_name,price,
        (case when order_date - join_date <= 6 then order_date 
        else null 
        end) as orders_in_first_week
    from sales s
    join members m on m.customer_id = s.customer_id
    and order_date >= join_date 
    join menu me on me.product_id = s.product_id
    where to_char(order_date,'YYYY-MM') <= '2021-01')
select customer_id , sum(price * 20) as points
from cte
where orders_in_first_week is not null
group by 1
order by points desc;

/* Bonus Questions
Join All The Things
The following questions are related creating basic data tables that Danny and his team can use 
to quickly derive insights without needing to join the underlying tables using SQL.*/

select s.customer_id,s.order_date,product_name,price,
    (case when order_date < join_date or join_date is null then 'N'
        when order_date >= join_date then 'Y'
        else null
        end) as member
from sales s
join menu m on m.product_id = s.product_id
left join members me on s.customer_id = me.customer_id
order by customer_id asc, order_date asc;

/* Rank All The Things
Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases so he expects 
null ranking values for the records when customers are not yet part of the loyalty program*/

with cte as
(select s.customer_id,
		s.order_date,
		mn.product_name,
		mn.price,
		(case when s.order_date < mb.join_date or join_date is null
		 then 'N' 
		 else 'Y' end) as members
from sales s
join menu mn on s.product_id = mn.product_id
left join members mb on s.customer_id = mb.customer_id
)
select *
	,case when members= 'N' then null 
			else rank() over(partition by customer_id,members
			order by customer_id,order_date) end as ranking
from cte;

