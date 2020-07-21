/* TASK 1 */

/*1.1 How many users are there per country, per geo area and per year of registration */

SELECT YEAR(date_sk) year_of_registration
, country_name
, geo_area
, COUNT(DISTINCT UUID) AS nr_users
FROM Users u INNER JOIN Country c 
ON  u.country_code = c.country_code
GROUP BY YEAR(date_sk)
, country_name
, geo_area


/* 1.2 How many purchases happened per country, per geo_area and per year of registration? */

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


/* 1.3 How many purchases are there per campaign, per subchannel and per month of
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


/* 1.4 Which is the Sales-to-Lead ratio (number of sales per purchase date / number of leads
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

/* 1.5 Which are the top 10 new sales revenues per subchannel per month of purchase?
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

						    
/*TASK 2: focuses on user sessions on the website and the handling of those
in our database 
						    
User events are grouped into sessions. We define a session as a sequence of events with the
same user ID, ordered by timestamp, such that the time difference between any consecutive
pair of events is at most one hour.*/

/* 2.1 How would you calculate the average session duration? */

SELECT AVG(DATEDIFF(minute,session_end, session_start)) avg_session_duration
FROM Sessions 


/* 2.2 How to know how many users have several sessions a day? How many sessions do
they do? (2.3)*/

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


-- Without nr_sessions_category, but per each number of sessions 
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

		  
/* Here instead of frequency of number of users per number of sessions (or number of sessions categories)
		    I show average number of users per nr of sessions (categories of number of sessions)*/

-- In this query I am showing how many users have 1, 2, 3 to 8 and more than 8 sessions per day. The output shows the frequency of number of users per
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


-- 2.3 How many sessions do they do?
		-- In this query firstly I count number sessions per date and user 
		-- Afterwards, I am taking average number of sessions if the number of sessions in the first subquery is more than 2 (possible to check more than 1, depending 
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
					

/* 2.4 Though in theory, a session_id is supposed to be unique, there happen to be duplicates.
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


/* TASK 3
Our conversion event looks similar to the structure shown below. In Snowflake, we can
use SQL syntax to query the events.
 */
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

-- Write a SQL query to find the number of distinct app_name and os_version
SELECT DISTINCT scr:meta.app_name::string
FROM events 

-- or  

SELECT scr:meta.app_name::string
FROM events 
GROUP BY 1


/* If there are two types of conversion like registrations and purchases, write a SQL to
calculate the average number of days between registrations and purchases per country
per campaign */ 

-- scr:created_at, scr:name, scr:type_of_conversion, scr:meta.country, scr:campaign_name
-- FLATTEN only meta. 

WITH base AS (
SELECT scr:name::string AS "name", scr:uuid::int AS "uuid", scr:created_at::date AS "created_at", scr:campaign_name::string AS "campaign_name"
, country.value::string AS "country"
FROM  events
	,   LATERAL FLATTEN (scr:meta) as meta
	,   LATERAL FLATTEN (meta.value:"country") as country 
	) 
	
	, t AS (
	SELECT  uuid, name, country, campaign_name
		, CASE WHEN type_of_conversion = "registrations" THEN created_at END AS reg_date 
		, CASE WHEN type_of_conversion = "purchases" THEN created_at END AS pur_date 
	FROM base
	WHERE type_of_conversion IN ("registrations", "purchases")
	GROUP BY uuid, conversion_event, country, campaign_name
	) 
	
	, t2 AS ( 
	SELECT country, campaign_name
	, DATEDIFF(day, pur_date, reg_date) AS days_diff
	FROM t 
	 ) 
	 
	SELECT country, campaign_name, AVG(days_diff) as avg_days_dif
	FROM t2 
	GROUP BY country, campaign_name
	



/* If there is another event name called “campaign_touchpoint”(i.e. different campaign
touchpoint which users’ contact point before he or she converted), write a SQL to identify
the first touchpoint channel, last touchpoint channel per user per session (default
session length = 30 mins). Your result must contain UUID, session_Id,
first_touchpoint_channel, last_touchpoint_channe */
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

/* I SQL Snowflake */ 

  WITH a0 AS (
   SELECT scr:uuid::int AS "uuid",  scr:created_at::datetime AS "created_at", scr:campaign_channel::string AS "campaign_channel"
   , scr:type_of_conversion::string AS "type_of_conversion", scr:name::string AS "event_name"
  FROM events
 GROUP BY scr:uuid::int, scr:created_at::datetime, cr:campaign_channel::string,  scr:type_of_conversion::string, scr:name::string
) 
   
  , a AS ( 
   
  SELECT uuid,
      created_at,
      SUM(is_new_session) OVER (ORDER BY uuid, created_at) AS global_session_id,
      SUM(is_new_session) OVER (PARTITION BY uuid ORDER BY created_at) AS user_session_id,
      campaign_channel,
      type_of_conversion
      FROM (
        SELECT *,
             CASE WHEN EXTRACT('EPOCH' FROM created_at) - EXTRACT('EPOCH' FROM last_event) >  (60 * 30) 
             OR last_event IS NULL
          THEN 1 ELSE 0 END AS is_new_session
         FROM (
              SELECT uuid,
                     created_at,
                     LAG(created_at,1) OVER (PARTITION BY uuid ORDER BY created_at) AS last_event, 
                     campaign_channel, 
                     type_of_conversion
                FROM a0
              ) last
      ) final 
           -- ORDER BY uuid, created_at, global_session_id, user_session_id
              )
          
              
  , first_touch AS ( 
     SELECT uuid, MIN(user_session_id) min_session_id
     FROM a 
     GROUP BY uuid
  )
       
    , last_first AS (
      SELECT a.uuid, a.user_session_id, global_session_id, created_at,
        campaign_channel, type_of_conversion
      , CASE WHEN type_of_conversion IN ("purchases","registrations")  THEN 'last_touchpoint'
            WHEN a.user_session_id = f.min_session_id THEN 'first_touchpoint'  END AS campaign_touchpoint
       
      FROM a LEFT JOIN first_touch f ON a.uuid = f.uuid AND a.user_session_id = f.min_session_id
      ORDER BY 1, 2
      ) 
       
   
      , last_touch3 AS (
      
      SELECT uuid, user_session_id, global_session_id, created_at, campaign_channel, type_of_conversion, campaign_touchpoint,
      "last_touchpoint" || "_" || CAST(rownum AS varchar)  AS last_touchpoint_seq
      
      FROM 
      (SELECT uuid, user_session_id, global_session_id, created_at, campaign_channel, type_of_conversion, campaign_touchpoint
      , ROW_NUMBER() OVER (PARTITION BY uuid ORDER BY user_session_id, created_at ) AS rownum 
      FROM last_first
      WHERE campaign_touchpoint = "last_touchpoint") last_touch2
        ) 
          
          
        , b AS ( 
        
        SELECT lf.uuid, lf.user_session_id, lf.global_session_id, lf.created_at, lf.type_of_conversion,  lf.campaign_channel, lf.campaign_touchpoint,
         last_touchpoint_seq
         FROM last_first lf LEFT JOIN last_touch3 l ON lf.uuid = l.uuid AND lf.user_session_id = l.user_session_id 
         AND  lf.campaign_channel  = l.campaign_channel AND lf.type_of_conversion = l.type_of_conversion
         ORDER BY 1, 2
        ) 
         
         
         SELECT uuid, user_session_id, global_session_id, created_at
        , MIN(CASE WHEN campaign_touchpoint = "first_touchpoint" THEN campaign_channel END) AS  first_touchpoint_channel
        --, MIN(CASE WHEN campaign_touchpoint = "last_touchpoint" THEN campaign_channel END) AS  last_touchpoint_channel
        , MIN(CASE WHEN last_touchpoint_seq = "last_touchpoint_1" THEN campaign_channel END ) AS last_touchpoint_channel1
        , MIN(CASE WHEN last_touchpoint_seq = "last_touchpoint_2" THEN campaign_channel END ) AS last_touchpoint_channel2
        , MIN(CASE WHEN last_touchpoint_seq = "last_touchpoint_3"THEN campaign_channel END ) AS last_touchpoint_channel3
         FROM b 
         WHERE campaign_touchpoint IS NOT NULL OR campaign_touchpoint != '' 
         GROUP BY  uuid, user_session_id, global_session_id, created_at
         ORDER BY 1, 2
  



/* Version in SQLite   */ 

   WITH a AS (
   
   SELECT uuid,
       created_at,
       SUM(is_new_session) OVER (ORDER BY uuid, created_at) AS global_session_id,
       SUM(is_new_session) OVER (PARTITION BY uuid ORDER BY created_at) AS user_session_id,
       campaign_channel,
       conversion
      FROM (
        SELECT *,
               CASE WHEN (strftime('%s',created_at) - strftime('%s',last_event))/60 > 30
             OR last_event IS NULL
           THEN 1 ELSE 0 END AS is_new_session
         FROM (
              SELECT uuid,
                     created_at,
                     LAG(created_at,1) OVER (PARTITION BY uuid ORDER BY created_at) AS last_event, 
                     campaign_channel, 
                     conversion
                FROM events
              ) last
       ) final 
            ORDER BY uuid, created_at, global_session_id, user_session_id
              )
          
              
  , first_touch AS ( 
     SELECT uuid, MIN(user_session_id) min_session_id
     FROM a 
     GROUP BY uuid
  )
       
      , last_touch AS (
      SELECT uuid, user_session_id, global_session_id, created_at,
        campaign_channel, conversion
      , CASE WHEN conversion = 1 THEN 'last_touchpoint' END AS campaign_touchpoint
       
      FROM a 
      ) 
       
      , b AS (
       SELECT l.uuid, user_session_id, global_session_id, created_at, campaign_channel, conversion,
       CASE WHEN campaign_touchpoint = "last_touchpoint"  THEN  'last_touchpoint'  
        WHEN l.user_session_id = f.min_session_id  THEN 'first_touchpoint'
        WHEN   l.user_session_id = f.min_session_id  AND  campaign_touchpoint = "last_touchpoint" THEN 'last_touchpoint' END  AS campaign_touchpoint --AND campaign_touchpoint != "last_touchpoint"
       FROM last_touch l LEFT JOIN first_touch f ON l.uuid = f.uuid AND l.user_session_id = f.min_session_id
       ) 
       
      , last_touch3 AS (
      
      SELECT uuid, user_session_id, global_session_id, created_at, campaign_channel, conversion, campaign_touchpoint,
      "last_touchpoint" || "_" || CAST(rownum AS varchar)  AS last_touchpoint_seq
      
      FROM 
      (SELECT uuid, user_session_id, global_session_id, created_at, campaign_channel, conversion, campaign_touchpoint
      , ROW_NUMBER() OVER (PARTITION BY uuid, campaign_channel ORDER BY user_session_id ) AS rownum 
      FROM b 
      WHERE campaign_touchpoint = "last_touchpoint") last_touch2
          ) 
          
          
         SELECT b.uuid, b.user_session_id, b.global_session_id, b.campaign_channel, b.campaign_touchpoint,
         last_touchpoint_seq
         FROM b LEFT JOIN last_touch3 l ON b.uuid = l.uuid AND b.user_session_id = l.user_session_id
       --  WHERE  b.campaign_touchpoint = "first_touchpoint" AND l.last_touchpoint_seq LIKE "last_touch%"
     
        ORDER BY 1, 2 
  
