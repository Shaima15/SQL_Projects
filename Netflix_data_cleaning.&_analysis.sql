-- Netflix Data cleaning and Analysis Project 

select * from netflix_raw
order by title --showed some titles with ??, after checking those in Jupyter notebook, it turns out that those ?? are in non-
-- english characters 

--Create a new table and convert the data type for 'title' from varchar to nvarchar 
-- Also, check change the characters from max to an appropriate number (refer to python code)
--drop the existing table 

drop TABLE [dbo].[netflix_raw]

-- create new table and check duplicates 

select count(*), show_id from netflix_raw
group by show_id
having Count(*) >1 --no duplicates so make it primary key 


Create TABLE [dbo].[netflix_raw](
	[show_id] [varchar](10) primary key,
	[type] [varchar](10) NULL,
	[title] [nvarchar](200) NULL,
	[director] [varchar](250) NULL,
	[cast] [varchar](1000) NULL,
	[country] [varchar](150) NULL,
	[date_added] [varchar](20) NULL,
	[release_year] [int] NULL,
	[rating] [varchar](10) NULL,
	[duration] [varchar](10) NULL,
	[listed_in] [varchar](100) NULL,
	[description] [varchar](500) NULL
) 

--Check if non-English characters are correctly expressed

select * from netflix_raw
where show_id= 's5023'

---------Data Cleaning section-----

--Check for duplicates in title 

select count(*), title from netflix_raw
group by title
having Count(*) >1 --shows duplicates, make sure by checking the full row 

select * from netflix_raw 
where title in (
select title from netflix_raw
group by title
having Count(*) >1 )
order by title 

--the above shows duplicates. however since the type for each title can differ, do the following 
select * from netflix_raw 
where concat(title, type) in (
select concat(title, type) from netflix_raw
group by title, type
having Count(*) >1 )
order by title 

--there are three duplicates that need to removed so create a temporary table and use partitions to aid the process

with cte as (
select *, row_number() over (partition by title, type order by show_id) as rn
from netflix_raw
)
select * 
from cte 
where rn=1

-- create separate tables for columns that have more than one value i.e director, cast, listed in, and country

-- director 

select show_id, trim(value) as director 
into netflix_directors
from netflix_raw
cross apply string_split (director, ',')

-- cast
select show_id, trim(value) as cast 
into netflix_cast
from netflix_raw
cross apply string_split (cast, ',')

-- country
select show_id, trim(value) as country
into netflix_country
from netflix_raw
cross apply string_split (country, ',')

--listed in 
select show_id, trim(value) as listed_in
into netflix_listed_in
from netflix_raw
cross apply string_split (listed_in, ',')

-- Now create final table that joins those newly created tables into one to ease analysis. 
--First convert date from varchar to date 

-- isnull() function on Jupyter Notebook shows that there is null values for directors, country, country, date_added, rating, 
--and duration 

-- Populate missing values for country 

-- Maps director and country to help with filling the missing data
insert into netflix_country
select show_id, m.country 
from netflix_raw nr
inner join (
select director, country
from netflix_country nc
inner join netflix_directors nd on nc.show_id = nd.show_id
group by director, country 
) m on nr.director = m.director
where nr.country is null

select nr.show_id, nc.country
from netflix_raw nr
inner join netflix_country nc on nr.show_id = nc.show_id

-- Populate missing values for duration and populate into final table

with cte as (
select *, row_number() over (partition by title, type order by show_id) as rn
from netflix_raw
)
select show_id, type, title, cast(date_added as date) as date_added, release_year, rating, case when duration is null 
then rating else duration end as duration, description
into netflix
from cte 

-----Data Analysis Section-----

-- 1) for each director count the no of movies and tv shows created using two separate columns and only include those 
-- who directed both movies and tv shows 

select nd.director, count(distinct case when n.type= 'Movie' then n.show_id end) as no_of_movies, 
count(distinct case when n.type= 'TV Show' then n.show_id end) as no_of_tvshow 
from netflix n 
inner join netflix_directors nd on n.show_id = nd.show_id
group by nd.director
having Count(distinct n.type) > 1

--2) which country has highest number of comedy movies

select top 1 nc.country, count(distinct nl.show_id) as no_of_movies
from netflix_listed_in nl
inner join netflix_country nc on nl.show_id = nc.show_id
inner join netflix n on n.show_id = nc.show_id
where nl.listed_in = 'Comedies' and n.type ='Movie'
group by nc.country
order by no_of_movies desc

--3) for each year (as per date added to netflix), which director has maximum number of movies released

with cte as (
select nd.director, Year(date_added) as date_year, count(n.show_id) as no_of_movies
from netflix n 
inner join netflix_directors nd on n.show_id= nd.show_id
where type= 'Movie'
group by nd.director, YEAR(date_added)
)
, cte2 as (
select * 
, ROW_NUMBER() over (partition by date_year order by no_of_movies desc, director) as rn
from cte )
select * from cte2 where rn= 1

--4) what is the average duration of movies in each genre

select nl.listed_in, AVG(cast(replace(duration, ' min','') As int)) as avg_duration
from netflix n 
inner join netflix_listed_in nl on n.show_id = nl.show_id
where type = 'Movie' 
group by nl.listed_in

--5) find the list of directors who have created horror and comedy movies both. display director names along with 
--number of comedy and horror movies directed by them

select nd.director, count(distinct case when nl.listed_in = 'Comedies' then n.show_id end) as no_of_comedy, 
count (distinct case when nl.listed_in = 'Horror Movies' then n.show_id end) as no_of_horror 
from netflix n 
inner join netflix_listed_in nl on n.show_id= nl.show_id
inner join netflix_directors nd on n.show_id = nd.show_id
where type = 'Movie' and nl.listed_in in ( 'Comedies', 'Horror Movies')
group by nd.director 
having count(distinct nl.listed_in) = 2




