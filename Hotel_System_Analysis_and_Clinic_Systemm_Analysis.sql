A. Given the below schema for a hotel management system, write appropriate query to answer the following :- 
1. For every user in the system, get the user_id and last booked room_no 

SQL Query:
WITH last_booking AS (
  SELECT
    user_id,
    room_no,
    booking_date,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY booking_date DESC) AS rn
  FROM bookings
)
SELECT user_id, room_no, booking_date
FROM last_booking
WHERE rn = 1;


2. Get booking_id and total billing amount of every booking created in November, 2021 

SQL Query:

SELECT
  b.booking_id,
  IFNULL(ba.booking_total, 0) AS booking_total
FROM bookings b
LEFT JOIN (
  SELECT
    bc.booking_id,
    SUM(bc.item_quantity * i.item_rate) AS booking_total
  FROM booking_commercials bc
  JOIN items i ON bc.item_id = i.item_id
  GROUP BY bc.booking_id
) ba ON ba.booking_id = b.booking_id
WHERE strftime('%Y', b.booking_date) = '2021'
  AND strftime('%m', b.booking_date) = '11';

3. Get bill_id and bill amount of all the bills raised in October, 2021 having bill amount >1000 

SQL Query:

SELECT
  bc.bill_id,
  SUM(bc.item_quantity * i.item_rate) AS bill_amount
FROM booking_commercials bc
JOIN items i ON bc.item_id = i.item_id
WHERE strftime('%Y', bc.bill_date) = '2021'
  AND strftime('%m', bc.bill_date) = '10'
GROUP BY bc.bill_id
HAVING SUM(bc.item_quantity * i.item_rate) > 1000;


4. Determine the most ordered and least ordered item of each month of year 2021 

SQL Query:

WITH monthly_totals AS (
  SELECT
    strftime('%Y', bc.bill_date) AS yr,
    strftime('%m', bc.bill_date) AS mon,
    bc.item_id,
    i.item_name,
    SUM(bc.item_quantity) AS total_qty
  FROM booking_commercials bc
  JOIN items i ON bc.item_id = i.item_id
  WHERE strftime('%Y', bc.bill_date) = '2021'
  GROUP BY yr, mon, bc.item_id, i.item_name
),
ranked AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY yr, mon ORDER BY total_qty DESC) AS rnk_desc,
    RANK() OVER (PARTITION BY yr, mon ORDER BY total_qty ASC)  AS rnk_asc
  FROM monthly_totals
)
SELECT yr, mon, item_id, item_name, total_qty, 'MOST' AS which
FROM ranked
WHERE rnk_desc = 1

UNION ALL

SELECT yr, mon, item_id, item_name, total_qty, 'LEAST' AS which
FROM ranked
WHERE rnk_asc = 1

ORDER BY yr, mon, which;


5. Find the customers with the second highest bill value of each month of year 2021 

SQL Query:

WITH bill_values AS (
  SELECT
    bc.bill_id,
    bc.booking_id,
    b.user_id,
    SUM(bc.item_quantity * i.item_rate) AS bill_amount,
    strftime('%Y', bc.bill_date) AS yr,
    strftime('%m', bc.bill_date) AS mon
  FROM booking_commercials bc
  JOIN items i ON bc.item_id = i.item_id
  LEFT JOIN bookings b ON bc.booking_id = b.booking_id
  WHERE strftime('%Y', bc.bill_date) = '2021'
  GROUP BY bc.bill_id, bc.booking_id, b.user_id, yr, mon
),
ranked AS (
  SELECT
    *,
    DENSE_RANK() OVER (PARTITION BY yr, mon ORDER BY bill_amount DESC) AS dr
  FROM bill_values
)
SELECT yr, mon, bill_id, booking_id, user_id, bill_amount
FROM ranked
WHERE dr = 2
ORDER BY yr, mon, bill_amount DESC;



B. For the below schema for a clinic management system, provide queries that solve for below questions :- 
1. Find the revenue we got from each sales channel in a given year 

SQL Query:

SELECT
  cs.sales_channel,
  SUM(cs.amount) AS revenue
FROM clinic_sales cs
WHERE strftime('%Y', cs.datetime) = :year
GROUP BY cs.sales_channel
ORDER BY revenue DESC;

2. Find top 10 the most valuable customers for a given year 

SQL Query:

SELECT
  c.uid,
  c.name,
  c.mobile,
  COALESCE(SUM(cs.amount), 0) AS total_spend
FROM customer c
LEFT JOIN clinic_sales cs
  ON c.uid = cs.uid
  AND strftime('%Y', cs.datetime) = :year
GROUP BY c.uid, c.name, c.mobile
ORDER BY total_spend DESC
LIMIT 10;

3. Find month wise revenue, expense, profit , status (profitable / not-profitable) for a given year

SQL Query:

WITH monthly_revenue AS (
  SELECT strftime('%m', datetime) AS mon, SUM(amount) AS revenue
  FROM clinic_sales
  WHERE strftime('%Y', datetime) = :year
  GROUP BY mon
),
monthly_expense AS (
  SELECT strftime('%m', datetime) AS mon, SUM(amount) AS expense
  FROM expenses
  WHERE strftime('%Y', datetime) = :year
  GROUP BY mon
)
SELECT
  m.mon,
  COALESCE(r.revenue, 0)   AS revenue,
  COALESCE(e.expense, 0)   AS expense,
  (COALESCE(r.revenue,0) - COALESCE(e.expense,0)) AS profit,
  CASE WHEN (COALESCE(r.revenue,0) - COALESCE(e.expense,0)) >= 0 THEN 'profitable' ELSE 'not-profitable' END AS status
FROM (
  -- ensure all 12 months appear if you prefer; this subselect returns only months present in either table
  SELECT mon FROM monthly_revenue
  UNION
  SELECT mon FROM monthly_expense
) m
LEFT JOIN monthly_revenue r ON m.mon = r.mon
LEFT JOIN monthly_expense e ON m.mon = e.mon
ORDER BY m.mon;

4. For each city find the most profitable clinic for a given month 

SQL Query:

WITH clinic_sales_month AS (
  SELECT
    cid,
    SUM(amount) AS revenue
  FROM clinic_sales
  WHERE strftime('%Y', datetime) = :year
    AND strftime('%m', datetime) = :month
  GROUP BY cid
),
clinic_expenses_month AS (
  SELECT
    cid,
    SUM(amount) AS expense
  FROM expenses
  WHERE strftime('%Y', datetime) = :year
    AND strftime('%m', datetime) = :month
  GROUP BY cid
),
clinic_profit AS (
  SELECT
    cl.cid,
    cl.clinic_name,
    cl.city,
    COALESCE(s.revenue, 0) AS revenue,
    COALESCE(e.expense, 0) AS expense,
    (COALESCE(s.revenue,0) - COALESCE(e.expense,0)) AS profit
  FROM clinics cl
  LEFT JOIN clinic_sales_month s ON cl.cid = s.cid
  LEFT JOIN clinic_expenses_month e ON cl.cid = e.cid
)
SELECT city, cid, clinic_name, revenue, expense, profit
FROM (
  SELECT
    cp.*,
    ROW_NUMBER() OVER (PARTITION BY city ORDER BY profit DESC) AS rn
  FROM clinic_profit cp
) t
WHERE rn = 1
ORDER BY city;

5. For each state find the second least profitable clinic for a given month 

SQL Query:

-- :year -> '2021', :month -> '09'
WITH clinic_sales_month AS (
  SELECT cid, SUM(amount) AS revenue
  FROM clinic_sales
  WHERE strftime('%Y', datetime) = :year AND strftime('%m', datetime) = :month
  GROUP BY cid
),
clinic_expenses_month AS (
  SELECT cid, SUM(amount) AS expense
  FROM expenses
  WHERE strftime('%Y', datetime) = :year AND strftime('%m', datetime) = :month
  GROUP BY cid
),
clinic_profit AS (
  SELECT
    cl.cid,
    cl.clinic_name,
    cl.state,
    COALESCE(s.revenue,0) AS revenue,
    COALESCE(e.expense,0) AS expense,
    (COALESCE(s.revenue,0) - COALESCE(e.expense,0)) AS profit
  FROM clinics cl
  LEFT JOIN clinic_sales_month s ON cl.cid = s.cid
  LEFT JOIN clinic_expenses_month e ON cl.cid = e.cid
)
SELECT state, cid, clinic_name, revenue, expense, profit
FROM (
  SELECT
    cp.*,
    ROW_NUMBER() OVER (PARTITION BY state ORDER BY profit ASC) AS rn
  FROM clinic_profit cp
) t
WHERE rn = 2
ORDER BY state;





