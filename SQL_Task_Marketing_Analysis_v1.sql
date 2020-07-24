/* TASK 3
Our conversion event looks similar to the structure shown below. In Snowflake, we can
use SQL syntax to query the events.
 */
{
'name': 'conversion_event'
'created_at' : 2020-01-01 00:00:00,
'uuid' : 12314512441312312,
'campaign_name': campaign_name1,
'campaign_channel': channel1,
'meta':{
'app_name': iOS,
'os_version': 11,
'country' : ABC,
'latitude': 12.12,
"longitude": 12.12,
},
"type_of_conversion": 'registrations'
}


-- 3.1 Write a SQL query to find the number of distinct app_name and os_version

-- I assume that the data are in Snowflake written in a VARIANT variable. I call this variable event_payload, and the table name is "event"

SELECT COUNT(DISTINCT event_payload:meta.app_name || event_payload:meta.os_version) AS nr_app_os_versions
FROM event

-- SELECT event_payload:meta.app_name::string AS "app_name", event_payload:meta.os_version::string AS "os_version"
-- FROM event
-- GROUP BY event_payload:meta.app_name, event_payload:meta.os_version
-- ;


/* 3.2. If there are two types of conversion like registrations and purchases, write a SQL to
calculate the average number of days between registrations and purchases per country
per campaign */ 


-- WITH base AS (
-- SELECT src:name::string AS "name", src:uuid::int AS "uuid", src:created_at::date AS "created_at", src:campaign_name::string AS "campaign_name"
-- ,   meta.value:"country"::string  -- or country.value::string AS "country" ? 
-- FROM  events
	-- ,   LATERAL FLATTEN (src:meta) as meta
--	,   LATERAL FLATTEN (meta.value:"country") as country    -- most probably it's not necessarily 
--	) 


WITH base AS ( 
	SELECT  event_payload:uuid::int AS uuid, event_payload:created_at::date AS created_at, event_payload:campaign_name::string AS campaign_name
	,  event_payload:meta:country::string AS country, event_payload:type_of_registration::string AS type_of_registration
	FROM event
	GROUP BY 1, 2, 3, 4, 5
)

, dates AS (
	SELECT    UUID, COUNTRY, CAMPAIGN_NAME
	, MIN(CASE WHEN TYPE_OF_REGISTRATION  = 'purchases' THEN created_at END) AS pur_date 
	FROM base
	WHERE  TYPE_OF_REGISTRATION IN ('registrations', 'purchases')
	GROUP BY UUID, COUNTRY, CAMPAIGN_NAME
	) 
	
	
, channel AS ( 
     SELECT uuid, country, min_reg_date, MIN(campaign_name) campaign_name_1reg 
     FROM  
     ( 
		 SELECT inter.uuid, country, min_reg_date, e.campaign_name
		  FROM base e
		  RIGHT JOIN 
			(	
			  SELECT uuid, MIN(created_at) min_reg_date
			  FROM base
			  WHERE TYPE_OF_REGISTRATION = 'registrations'
			  GROUP BY uuid ) AS inter
      
			ON e.uuid = inter.uuid AND e.created_at = inter.min_reg_date ) AS inter2 
	  
      GROUP BY uuid, country, min_reg_date 
      ) 
	  
    
	
, diff AS (
	SELECT d.country, campaign_name_1reg, DATEDIFF(day, min_reg_date, pur_date) days_diff
	FROM dates d LEFT JOIN channel c  ON d.uuid = c.uuid
     WHERE pur_date IS NOT NULL AND min_reg_date IS NOT NULL
     )
	 
 SELECT country, campaign_name_1reg, ROUND(AVG(days_diff)) AS avg_days_diff
 FROM diff 
 GROUP BY country, campaign_name_1reg
	 ;
	 


/* 3.3 If there is another event name called “campaign_touchpoint”(i.e. different campaign
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

/* In SQL Snowflake */ 

  -- WITH a0 AS (
   -- SELECT src:uuid::int AS "uuid",  src:created_at::datetime AS "created_at", src:campaign_channel::string AS "campaign_channel"
   -- , src:type_of_conversion::string AS "type_of_conversion", src:name::string AS "event_name"
  -- FROM events
 -- GROUP BY src:uuid::int, src:created_at::datetime, cr:campaign_channel::string,  src:type_of_conversion::string, src:name::string
-- ) 

WITH base AS ( 
SELECT  event_payload:uuid::int AS uuid, event_payload:created_at::date AS created_at, event_payload:campaign_channel::string AS channel
,  event_payload:type_of_registration::string AS type_of_registration
FROM event
GROUP BY 1, 2, 3, 4
)
   
  , sessions AS ( 
   
  SELECT uuid,
      created_at,
      SUM(is_new_session) OVER (ORDER BY uuid, created_at) AS global_session_id,
      SUM(is_new_session) OVER (PARTITION BY uuid ORDER BY created_at) AS user_session_id,
      channel,
      type_of_registration
      FROM (
        SELECT *,
             CASE WHEN DATEDIFF(minute, last_event, created_at) >  30 
             OR last_event IS NULL
          THEN 1 ELSE 0 END AS is_new_session
         FROM (
              SELECT uuid,
                     created_at,
                     LAG(created_at,1) OVER (PARTITION BY uuid ORDER BY created_at) AS last_event, 
                     channel, 
                     type_of_registration
                FROM base
              ) last
      ) final 
           -- ORDER BY uuid, created_at, global_session_id, user_session_id
              )
          
              
  , first_touch AS ( 
     SELECT uuid, MIN(user_session_id) min_session_id
     FROM sessions
     GROUP BY uuid
  )
       
   , last_first AS (
      SELECT s.uuid, s.user_session_id, global_session_id, created_at, channel, type_of_registration
      , CASE WHEN type_of_registration IN ('purchases','registrations')  THEN 'last_touchpoint'
            WHEN s.user_session_id = f.min_session_id THEN 'first_touchpoint'  END AS campaign_touchpoint
       
      FROM sessions s LEFT JOIN first_touch f ON s.uuid = f.uuid AND s.user_session_id = f.min_session_id
      ORDER BY 1, 2
      ) 
       
   
      , last_touch3 AS (
      
      SELECT uuid, user_session_id, global_session_id, created_at, channel, type_of_registration, campaign_touchpoint,
      'last_touchpoint' || '_' || CAST(rownum AS varchar)  AS last_touchpoint_seq
      
      FROM 
      (SELECT uuid, user_session_id, global_session_id, created_at, channel, type_of_registration, campaign_touchpoint
      , ROW_NUMBER() OVER (PARTITION BY uuid ORDER BY user_session_id, created_at ) AS rownum 
      FROM last_first
      WHERE campaign_touchpoint = 'last_touchpoint') last_touch2
        ) 
          
          
        , b AS ( 
        
        SELECT lf.uuid, lf.user_session_id, lf.global_session_id, lf.created_at, lf.type_of_registration,  lf.channel, lf.campaign_touchpoint,
         last_touchpoint_seq
         FROM last_first lf LEFT JOIN last_touch3 l ON lf.uuid = l.uuid AND lf.user_session_id = l.user_session_id 
         AND  lf.channel  = l.channel AND lf.type_of_registration = l.type_of_registration
         ORDER BY 1, 2
        ) 
         
         
         SELECT uuid, user_session_id, global_session_id, created_at
        , MIN(CASE WHEN campaign_touchpoint = 'first_touchpoint' THEN channel END) AS  first_touchpoint_channel
        --, MIN(CASE WHEN campaign_touchpoint = 'last_touchpoint' THEN campaign_channel END) AS  last_touchpoint_channel
        , MIN(CASE WHEN last_touchpoint_seq = 'last_touchpoint_1' THEN channel  END ) AS last_touchpoint_channel1
        , MIN(CASE WHEN last_touchpoint_seq = 'last_touchpoint_2' THEN channel  END ) AS last_touchpoint_channel2
        , MIN(CASE WHEN last_touchpoint_seq = 'last_touchpoint_3'THEN channel  END ) AS last_touchpoint_channel3
         FROM b 
         WHERE campaign_touchpoint IS NOT NULL OR campaign_touchpoint != '' 
         GROUP BY  uuid, user_session_id, global_session_id, created_at
         ORDER BY 1, 2
  



/* TASK 1 */

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
JOIN Users u ON s.UUID = u.UUID
JOIN Country c ON u.country_code = c.country_code
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
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), '-',CAST(MONTH(s.date_sk) AS varchar )) 


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
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), '-',CAST(MONTH(s.date_sk) AS varchar )) year_month
, SUM(price_eu) sales_revenue
FROM Sales s INNER JOIN Revenue r 
ON s.purchase_id = r.purchase_id 
INNER JOIN Campaigns c 
ON s.campaign_id = c.campaign_id
WHERE is_first_period = 'first_sale'
GROUP BY 
sub_channel
, YEAR(s.date_sk)
, MONTH(s.date_sk) 
, CONCAT(CAST(YEAR(s.date_sk) AS varchar), '-',CAST(MONTH(s.date_sk) AS varchar ))
ORDER BY 5 desc 
LIMIT 10

/*TASK 2: focuses on user sessions on the website and the handling of those
in our database */

/* User events are grouped into sessions. We define a session as a sequence of events with the
same user ID, ordered by timestamp, such that the time difference between any consecutive
pair of events is at most one hour.*/

/* 2.1. How would you calculate the average session duration? */

SELECT AVG(DATEDIFF(minute,session_start, session_end)) avg_session_duration
FROM Sessions 


/* 2.2. How to know how many users have several sessions a day? How many sessions do
they do?*/

-- How to know how many users have several sessions a day?
-- This query shows how many users have 1, 2, 3 to 8 and more than 8 sessions per day. The output shows the frequency of number of users per
-- nr_sessions_category 



WITH users_with_more_sessions_day AS (
SELECT uuid, date_start::DATE, COUNT(DISTINCT session_id) AS sessions_per_day
FROM sessions
GROUP BY 1,2
HAVING sessions_per_day > 1
)
SELECT COUNT(*) FROM users_with_more_sessions_day




-- How many sessions do they do?
		-- In this query firstly I count number sessions per date and user 
		-- Afterwards I am taking average number of sessions if the number of sessions in the first subquery I more than 2 (possible to check more than 1, depending 
		-- on what interests you )
		

WITH t1 AS (
SELECT uuid 
, DATE(session_start) date
, COUNT(session_id) nr_sessions
FROM sessions 
GROUP BY 
uuid
, DATE(session_start)
					)
SELECT 
AVG(nr_sessions)
	FROM t1
	WHERE nr_sessions > 1;
					

/*Though in theory, a session_id is supposed to be unique, there happen to be duplicates.
How would you proceed to find and remove them? */

SELECT uuid
, session_id
, session_start
, session_end
FROM 
sessions 

EXCEPT

SELECT uuid, session_id, session_start, session_end
FROM 
(
SELECT s1.uuid
, s1.session_id
, s1.session_start
, s1.session_end
, ROW_NUMBER() OVER (PARTITION BY s1.uuid ORDER BY s1.uuid ) AS rownum
FROM sessions s1
JOIN 
sessions s2
WHERE s1.uuid = s2.uuid 
AND s1.session_start >= s2.session_start AND s1.session_end <= s2.session_end
AND s1.session_id != s2.session_id 
) AS t
WHERE rownum > 1
