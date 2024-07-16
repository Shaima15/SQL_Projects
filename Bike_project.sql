-- Bike Project 

--Combined two tables through union instead of union all because the latter includes duplicates as well
-- Created a CTE table so it will be possible to combine all the three tables into one

With cte as (Select * from bike_share_yr_0
union 
Select * from bike_share_yr_1)

-- Join the cte with the cost table using left join 

Select dteday, season, a.yr, weekday, hr, rider_type, riders, price, riders * price as revenue, riders * price - COGS as profit,
COGS from cte a
left join cost_table b
on a.yr = b.yr



