/* Task 1 represents the business model */

/*How many users are there per country, per geo area and per year of registration */



SELECT YEAR(date_sk) year_of_registration
, country_name
, geo_area
, COUNT(DISTINCT UUID) AS nr_users
FROM Users u INNER JOIN Country c 
ON  u.country_code = c.country_code
GROUP BY YEAR(date_sk)
, country_name
, geo_area


/*How many purchases happened per country, per geo_area and per year of registration? */

SELECT YEAR(u.date_sk) year_of_registration
, country_name
, geo_area
, COUNT(DISTINCT purchase_id) nr_purchases
FROM Sales s 
LEFT JOIN Users u ON s.UUID = u.UUID
LEFT JOIN Country c ON u.country_code = c.country_code
GROUP BY YEAR(u.date_sk) 
, country_name
, geo_area

/* How many purchases are there per campaign, per subchannel and per month of
purchase? */

SELECT campaign_name
, sub_channel
, YEAR(s.date_sk) year
, MONTH(s.date_sk) month
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), "-",CAST(MONTH(s.date_sk) AS varchar )) AS year_month
, COUNT(DISTINCT purchase_id) nr_purchases
FROM Sales s 
LEFT JOIN Campaigns c  ON s.campaign_id = c.campaign_id 
GROUP BY  campaign_name
, sub_channel
, YEAR(s.date_sk) 
, MONTH(s.date_sk) 
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), "-",CAST(MONTH(s.date_sk) AS varchar )) 


/* Which is the Sales-to-Lead ratio (number of sales per purchase date / number of leads
per registration date) per campaign and per date?*/

WITH sales AS (

SELECT campaign_name
, DATE(s.date_sk) date
, COUNT(DISTINCT purchase_id) nr_sales
FROM Sales s
LEFT JOIN Campaigns c ON s.campaign_id = c.campaign_id
GROUP BY campaign_name
, DATE(s.date_sk))

, leads AS (

SELECT campaign_name
, DATE(u.date_sk) date
COUNT(DISTINCT UUID) nr_leads
FROM Users u 
LEFT JOIN Campaigns c ON u.campaign_id = c.campaign_id
GROUP BY campaign_name
, DATE(u.date_sk) )

SELECT ROUND(nr_sales/CAST(nr_sales AS DECIMAL),4) AS sales_to_lead_ratio 
FROM sales RIGHT JOIN leads
ON sales.date = leads.date AND sales.campaign_name = leads_campaign_name

/*Which are the top 10 new sales revenues per subchannel per month of purchase?
Hint: New Sales Revenues: purchase_transaction_ID with is_first_period = 'first_sale'
*/

SELECT sub_channel
, YEAR(s.date_sk) year
, MONTH(s.date_sk) month
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), "-",CAST(MONTH(s.date_sk) AS varchar )) year_month
, SUM(price_eu) sales_revenue
FROM Sales s INNER JOIN Revenue r 
ON s.purchase_id = r.purchase_id 
LEFT JOIN Campaigns c 
ON s.campaign_id = c.campaign_id
WHERE is_first_period = 'first_sale'
GROUP BY 
sub_channel
, YEAR(s.date_sk)
, MONTH(s.date_sk) 
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), "-",CAST(MONTH(s.date_sk) AS varchar ))

/*Task2 : focuses on user sessionson the website and the handling of those
in our database */

/* User events are grouped into sessions. We define a session as a sequence of events with the
same user ID, ordered by timestamp, such that the time difference between any consecutive
pair of events is at most one hour.*/

/* How would you calculate the average session duration? */

SELECT AVG(DATEDIFF(minute,session_end, session_start)) avg_session_duration
FROM Sessions 


/*How to know how many users have several sessions a day? How many sessions do
they do?*/

-- How to know how many users have several sessions a day?
-- This query shows how many users have 1, 2, 3 to 8 and more than 8 sessions per day. The output shows the frequency of number of users per
-- nr_sessions_category 


WITH t1 AS (
SELECT uuid 
, DATE(date_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid, DATE(date_start)
					)

, t2 AS (
SELECT uuid
, date
, nr_sessions
, CASE WHEN nr_sessions = 1 THEN "one_session"
					WHEN nr_sessions = 2 THEN "two_sessions"
					WHEN nr_sessions > 2 AND nr_sessions < 9 THEN "several_sessions_more_than2"
					ELSE "nine_or_more" END AS nr_sessions_categories
	FROM t1
 					)
, t3 AS (
SELECT  date 
 , nr_sessions_categories
 , COUNT(DISTINCT uuid) nr_users
FROM t2 
WHERE nr_sessions_categories != "one_session"
GROUP BY date
) 

SELECT nr_sessions_categories, nr_users, COUNT(*) AS frequency
FROM t3
GROUP BY 1, 2
ORDER BY 1, 3, 2
;


-- Without nr_sessions_category 
WITH t1 AS (
SELECT uuid 
, DATE(date_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid, DATE(date_start)
					)

, t2 AS (
SELECT uuid
, date
, nr_sessions
, CASE WHEN nr_sessions = 1 THEN "one_session"
					WHEN nr_sessions = 2 THEN "two_sessions"
					WHEN nr_sessions > 2 AND nr_sessions < 9 THEN "several_sessions_more_than2"
					ELSE "nine_or_more" END AS nr_sessions_categories
	FROM t1
 					)
, t3 AS (
SELECT  date 
 , nr_sessions
 , COUNT(DISTINCT uuid) nr_users
FROM t2 
--WHERE nr_sessions_categories != "one_session"
GROUP BY date, nr_sessions
) 

SELECT nr_sessions, nr_users, COUNT(*) AS frequency
FROM t3
GROUP BY 1, 2
ORDER BY 1, 3 desc, 2

-- In this query show how many users have 1, 2, 3 to 8 and more than 8 sessions per day. The output shows the frequency of number of users per
-- nr_sessions_category 

WITH t1 AS (
SELECT uuid 
, DATE(date_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid, DATE(date_start)
					)

, t2 AS (
SELECT uuid
, date
, nr_sessions
, CASE WHEN nr_sessions = 1 THEN "one_session"
					WHEN nr_sessions = 2 THEN "two_sessions"
					WHEN nr_sessions > 2 AND nr_sessions < 9 THEN "several_sessions_more_than2"
					ELSE "nine_or_more" END AS nr_sessions_categories
	FROM t1
 					)
, t3 AS (
SELECT  date 
 , nr_sessions_categories
 , COUNT(DISTINCT uuid) nr_users
FROM t2 
--WHERE nr_sessions_categories != "one_session"
GROUP BY date
) 

SELECT nr_sessions_categories
, AVG(nr_users) avg_number_users
FROM t3
GROUP BY 1
ORDER BY 1, 2 desc
;

-- per each number of sessions without groupping by nr_sessions_category
WITH t1 AS (
SELECT uuid 
, DATE(date_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid, DATE(date_start)
					)

, t2 AS (
SELECT uuid
, date
, nr_sessions
, CASE WHEN nr_sessions = 1 THEN "one_session"
					WHEN nr_sessions = 2 THEN "two_sessions"
					WHEN nr_sessions > 2 AND nr_sessions < 9 THEN "several_sessions_more_than2"
					ELSE "nine_or_more" END AS nr_sessions_categories
	FROM t1
 					)
, t3 AS (
SELECT  date 
 , nr_sessions
 , COUNT(DISTINCT uuid) nr_users
FROM t2 
--WHERE nr_sessions_categories != "one_session"
GROUP BY date, nr_sessions
) 

SELECT nr_sessions, AVG(nr_users) avg_number_users
FROM t3
GROUP BY 1
ORDER BY 1, 2 desc;


-- How many sessions do they do?
		-- In this query firstly I count number sessions per date and user 
		-- Afterwards I am taking average number of sessions if the number of sessions in the first subquery I more than 2 (possible to check more than 1, depending 
		-- on what interests you )
		

WITH t1 AS (
SELECT uuid 
, DATE(date_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid
, DATE(date_start)
					)
SELECT 
AVG(nr_sessions)
	FROM t1
	WHERE nr_sessions > 2;
					

/*Though in theory, a session_id is supposed to be unique, there happen to be duplicates.
How would you proceed to find and remove them? */

SELECT uuid
, session_id
, date_start
, date_end
FROM 
sessions 

EXCEPT

SELECT uuid, session_id, date_start, date_end
FROM 
(
SELECT s1.uuid
, s1.session_id
, s1.date_start
, s1.date_end
, ROW_NUMBER() OVER (PARTITION BY s1.uuid ORDER BY s1.uuid ) AS rownum
FROM sessions s1
JOIN 
sessions s2
WHERE s1.uuid = s2.uuid 
AND s1.date_start >= s2.date_start AND s1.date_end <= s2.date_end
AND s1.session_id != s2.session_id 
) AS t
WHERE rownum > 1





/* TASK 3 If there are two types of conversion like registrations and purchases, write a SQL to
calculate the average number of days between registrations and purchases per country
per campaign. */
{
"name": 'conversion_event'
"created_at" : 2020-01-01 00:00:00,
"uuid" : 12314512441312312,
"campaign_name": campaign_name1,
"campaign_channel": channel1,
"meta":{
"app_name": iOS,
"os_version": 11,
"country" : ABC,
"latitude": 12.12,
"longitude": 12.12,
},
"type_of_conversion": 'registrations'
}

WITH a AS (SELECT UUID, campaign_name, country
, CASE WHEN type_of_conversion = "registrations" THEN created_at END AS reg_date 
, CASE WHEN type_of_conversion = "purchases" THEN created_at END AS pur_date 
FROM Events 

SELECT campaign_name, country, AVG(DATEDIFF(day, pur_date, reg_date)) days_diff
FROM a
WHERE reg_data IS NOT NULL AND pur_date IS NOT NULL
GROUP BY campaign_name, country

