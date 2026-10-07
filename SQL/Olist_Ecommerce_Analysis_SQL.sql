/* ============================================================
   OLIST E-COMMERCE ANALYSIS
   Delivery & Customer Satisfaction Analysis
   ============================================================

   Author: Nicole Paiz
   
   Project Purpose:
   Analyze Olist e-commerce order and customer review data to
   evaluate delivery performance, examine its relationship to
   customer satisfaction, and identify business insights that
   could support improvements to the customer experience.

   Tools:
   - PostgreSQL / pgAdmin
   - Microsoft Excel
   - Power BI

   Dataset:
   Brazilian E-Commerce Public Dataset by Olist
   Source: Kaggle

   Main Analysis Areas:
   1. Database & Table Setup
   2. Delivery Performance
   3. Customer Reviews & Satisfaction
   4. Delivery Delay Analysis
   5. Product & Category Analysis
   6. Time-Based Analysis
   7. Seller Analysis
   8. Power BI Dataset Development
   9. Power BI View
   ============================================================ */


/* ============================================================
   SECTION 1: DATABASE & TABLE SETUP
   ============================================================ */


/* ------------------------------------------------------------
   1.1 Create the Olist schema
   ------------------------------------------------------------ */

CREATE SCHEMA IF NOT EXISTS olist;


/* ------------------------------------------------------------
   1.2 Create Orders table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.orders (
    order_id VARCHAR(32),
    customer_id VARCHAR(32),
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);


/* ------------------------------------------------------------
   1.3 Create Reviews table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.reviews (
    review_id VARCHAR(32),
    order_id VARCHAR(32),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);


/* ------------------------------------------------------------
   1.4 Create Order Items table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.order_items (
    order_id VARCHAR(32),
    order_item_id INTEGER,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2)
);


/* ------------------------------------------------------------
   1.5 Create Products table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.products (
    product_id VARCHAR(32),
    product_category_name VARCHAR(100),
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(10,2),
    product_length_cm NUMERIC(10,2),
    product_height_cm NUMERIC(10,2),
    product_width_cm NUMERIC(10,2)
);


/* ------------------------------------------------------------
   1.6 Create Category Translation table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);


/* ------------------------------------------------------------
   1.7 Create Customers table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id VARCHAR(32),
    customer_unique_id VARCHAR(32),
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(2)
);


/* ------------------------------------------------------------
   1.8 Create Sellers table
   ------------------------------------------------------------ */

CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id VARCHAR(32),
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state VARCHAR(2)
);


/*
   NOTE:
   Data was imported into these tables using pgAdmin's
   Import/Export Data functionality. Local file paths are not
   included in this script because they are specific to the
   computer/environment where the project was created.
*/


/* ============================================================
   SECTION 2: DELIVERY PERFORMANCE ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   2.1 Check total orders and delivery-date completeness
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_orders,
    COUNT(order_purchase_timestamp) AS orders_with_purchase_date,
    COUNT(order_estimated_delivery_date) AS orders_with_estimated_date,
    COUNT(order_delivered_customer_date) AS orders_with_customer_delivery_date
FROM olist.orders;


/* ------------------------------------------------------------
   2.2 Check missing delivery information
   ------------------------------------------------------------ */

SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS missing_approved_date,

    COUNT(*) FILTER (
        WHERE order_delivered_carrier_date IS NULL
    ) AS missing_carrier_date,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_customer_delivery_date,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS missing_estimated_delivery_date
FROM olist.orders;


/* ------------------------------------------------------------
   2.3 Review order status distribution
   ------------------------------------------------------------ */

SELECT
    order_status,
    COUNT(*) AS order_count
FROM olist.orders
GROUP BY order_status
ORDER BY order_count DESC;


/* ------------------------------------------------------------
   2.4 Classify delivered orders as On Time, Late, or Missing
   ------------------------------------------------------------ */

SELECT
    CASE
        WHEN order_delivered_customer_date IS NULL
            THEN 'Missing Delivery Date'

        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On Time'

        ELSE 'Late'
    END AS delivery_performance,

    COUNT(*) AS order_count
FROM olist.orders
WHERE order_status = 'delivered'
GROUP BY
    CASE
        WHEN order_delivered_customer_date IS NULL
            THEN 'Missing Delivery Date'

        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On Time'

        ELSE 'Late'
    END
ORDER BY order_count DESC;


/* ------------------------------------------------------------
   2.5 Calculate on-time and late delivery rates
   ------------------------------------------------------------ */

WITH delivery_status AS (
    SELECT
        CASE
            WHEN order_delivered_customer_date IS NULL
                THEN 'Missing'

            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_performance
    FROM olist.orders
    WHERE order_status = 'delivered'
)

SELECT
    delivery_performance,
    COUNT(*) AS order_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM delivery_status
GROUP BY delivery_performance
ORDER BY order_count DESC;


/* ------------------------------------------------------------
   2.6 Calculate average delivery difference

   Positive value = delivered after estimated date
   Negative value = delivered before estimated date
   ------------------------------------------------------------ */

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS average_delivery_difference_days
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


/* ------------------------------------------------------------
   2.7 Calculate delivery difference range
   ------------------------------------------------------------ */

SELECT
    ROUND(
        MIN(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS minimum_difference_days,

    ROUND(
        MAX(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS maximum_difference_days
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


/* ============================================================
   SECTION 3: CUSTOMER REVIEWS & SATISFACTION ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   3.1 Review record count
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_review_records,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS unique_orders_with_reviews
FROM olist.reviews;


/* ------------------------------------------------------------
   3.2 Check for multiple reviews associated with an order
   ------------------------------------------------------------ */

SELECT
    order_id,
    COUNT(*) AS review_count
FROM olist.reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY review_count DESC;


/* ------------------------------------------------------------
   3.3 Count how many orders have multiple reviews
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT
        order_id
    FROM olist.reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS multiple_reviews;


/* ------------------------------------------------------------
   3.4 Review score distribution
   ------------------------------------------------------------ */

SELECT
    review_score,
    COUNT(*) AS review_count
FROM olist.reviews
GROUP BY review_score
ORDER BY review_score;


/* ------------------------------------------------------------
   3.5 Overall average review score

   Multiple reviews for the same order are averaged at the
   order level so that each order contributes equally.
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
)

SELECT
    ROUND(AVG(average_review_score), 2) AS overall_average_review_score
FROM order_reviews;


/* ------------------------------------------------------------
   3.6 Average review score for delivered orders
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
)

SELECT
    ROUND(AVG(r.average_review_score), 2)
        AS delivered_orders_average_review_score
FROM olist.orders AS o
INNER JOIN order_reviews AS r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered';


/* ------------------------------------------------------------
   3.7 Compare review scores by delivery performance
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
),

delivery_status AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date IS NULL
                THEN 'Missing'

            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_performance

    FROM olist.orders
    WHERE order_status = 'delivered'
)

SELECT
    d.delivery_performance,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.average_review_score), 2)
        AS average_review_score
FROM delivery_status AS d
INNER JOIN order_reviews AS r
    ON d.order_id = r.order_id
GROUP BY d.delivery_performance
ORDER BY d.delivery_performance;


/* ------------------------------------------------------------
   3.8 Categorize order-level review scores

   Low     = below 3
   Neutral = 3 to below 4
   High    = 4 or higher
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
)

SELECT
    CASE
        WHEN average_review_score < 3
            THEN 'Low'

        WHEN average_review_score < 4
            THEN 'Neutral'

        ELSE 'High'
    END AS review_category,

    COUNT(*) AS order_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM order_reviews
GROUP BY
    CASE
        WHEN average_review_score < 3
            THEN 'Low'

        WHEN average_review_score < 4
            THEN 'Neutral'

        ELSE 'High'
    END
ORDER BY review_category;


/* ------------------------------------------------------------
   3.9 Review category by delivery performance
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
),

order_delivery AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_performance
    FROM olist.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    d.delivery_performance,

    CASE
        WHEN r.average_review_score < 3
            THEN 'Low'

        WHEN r.average_review_score < 4
            THEN 'Neutral'

        ELSE 'High'
    END AS review_category,

    COUNT(*) AS order_count,

    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (
            PARTITION BY d.delivery_performance
        ),
        2
    ) AS percentage
FROM order_delivery AS d
INNER JOIN order_reviews AS r
    ON d.order_id = r.order_id
GROUP BY
    d.delivery_performance,
    CASE
        WHEN r.average_review_score < 3
            THEN 'Low'

        WHEN r.average_review_score < 4
            THEN 'Neutral'

        ELSE 'High'
    END
ORDER BY
    d.delivery_performance,
    review_category;


/* ============================================================
   SECTION 4: DELIVERY DELAY ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   4.1 Calculate average delay for late orders
   ------------------------------------------------------------ */

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS average_days_late
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date
      > order_estimated_delivery_date;


/* ------------------------------------------------------------
   4.2 Calculate minimum and maximum delay
   ------------------------------------------------------------ */

SELECT
    ROUND(
        MIN(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS minimum_days_late,

    ROUND(
        MAX(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        ),
        2
    ) AS maximum_days_late
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date
      > order_estimated_delivery_date;


/* ------------------------------------------------------------
   4.3 Create delivery delay bands

   These bands are used to make delay severity easier to
   analyze and visualize in Power BI.
   ------------------------------------------------------------ */

WITH late_orders AS (
    SELECT
        order_id,

        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_estimated_delivery_date
            )
        ) / 86400.0 AS days_late

    FROM olist.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date
          > order_estimated_delivery_date
)

SELECT
    CASE
        WHEN days_late <= 2
            THEN '0–2 days'

        WHEN days_late <= 7
            THEN '3–7 days'

        WHEN days_late <= 14
            THEN '8–14 days'

        WHEN days_late <= 30
            THEN '15–30 days'

        ELSE '31+ days'
    END AS delay_band,

    COUNT(*) AS late_order_count

FROM late_orders

GROUP BY
    CASE
        WHEN days_late <= 2
            THEN '0–2 days'

        WHEN days_late <= 7
            THEN '3–7 days'

        WHEN days_late <= 14
            THEN '8–14 days'

        WHEN days_late <= 30
            THEN '15–30 days'

        ELSE '31+ days'
    END

ORDER BY
    CASE
        WHEN
            CASE
                WHEN days_late <= 2 THEN '0–2 days'
                WHEN days_late <= 7 THEN '3–7 days'
                WHEN days_late <= 14 THEN '8–14 days'
                WHEN days_late <= 30 THEN '15–30 days'
                ELSE '31+ days'
            END = '0–2 days'
            THEN 1

        WHEN
            CASE
                WHEN days_late <= 2 THEN '0–2 days'
                WHEN days_late <= 7 THEN '3–7 days'
                WHEN days_late <= 14 THEN '8–14 days'
                WHEN days_late <= 30 THEN '15–30 days'
                ELSE '31+ days'
            END = '3–7 days'
            THEN 2

        WHEN
            CASE
                WHEN days_late <= 2 THEN '0–2 days'
                WHEN days_late <= 7 THEN '3–7 days'
                WHEN days_late <= 14 THEN '8–14 days'
                WHEN days_late <= 30 THEN '15–30 days'
                ELSE '31+ days'
            END = '8–14 days'
            THEN 3

        WHEN
            CASE
                WHEN days_late <= 2 THEN '0–2 days'
                WHEN days_late <= 7 THEN '3–7 days'
                WHEN days_late <= 14 THEN '8–14 days'
                WHEN days_late <= 30 THEN '15–30 days'
                ELSE '31+ days'
            END = '15–30 days'
            THEN 4

        ELSE 5
    END;


/* ------------------------------------------------------------
   4.4 Analyze review scores by delay severity
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
),

late_orders AS (
    SELECT
        order_id,

        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_estimated_delivery_date
            )
        ) / 86400.0 AS days_late

    FROM olist.orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_delivered_customer_date
          > order_estimated_delivery_date
)

SELECT
    CASE
        WHEN l.days_late <= 2
            THEN '0–2 days'

        WHEN l.days_late <= 7
            THEN '3–7 days'

        WHEN l.days_late <= 14
            THEN '8–14 days'

        WHEN l.days_late <= 30
            THEN '15–30 days'

        ELSE '31+ days'
    END AS delay_band,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(r.average_review_score),
        2
    ) AS average_review_score

FROM late_orders AS l

INNER JOIN order_reviews AS r
    ON l.order_id = r.order_id

GROUP BY
    CASE
        WHEN l.days_late <= 2
            THEN '0–2 days'

        WHEN l.days_late <= 7
            THEN '3–7 days'

        WHEN l.days_late <= 14
            THEN '8–14 days'

        WHEN l.days_late <= 30
            THEN '15–30 days'

        ELSE '31+ days'
    END

ORDER BY
    average_review_score;


/* ============================================================
   SECTION 5: PRODUCT & CATEGORY ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   5.1 Product category overview
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS total_products,

    COUNT(product_category_name)
        AS products_with_category,

    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS products_missing_category,

    COUNT(DISTINCT product_category_name)
        AS unique_categories

FROM olist.products;


/* ------------------------------------------------------------
   5.2 Identify product categories without English translations
   ------------------------------------------------------------ */

SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM olist.products AS p
LEFT JOIN olist.category_translation AS ct
    ON p.product_category_name
       = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;


/* ------------------------------------------------------------
   5.3 Check category translation coverage
   ------------------------------------------------------------ */

SELECT
    COUNT(DISTINCT product_category_name)
        AS translated_category_count
FROM olist.category_translation;


/* ------------------------------------------------------------
   5.4 Analyze number of items per order
   ------------------------------------------------------------ */

WITH items_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM olist.order_items
    GROUP BY order_id
)

SELECT
    MIN(item_count) AS minimum_items_per_order,
    ROUND(AVG(item_count), 2) AS average_items_per_order,
    MAX(item_count) AS maximum_items_per_order
FROM items_per_order;


/* ------------------------------------------------------------
   5.5 Single-item vs multi-item orders
   ------------------------------------------------------------ */

WITH items_per_order AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM olist.order_items
    GROUP BY order_id
)

SELECT
    CASE
        WHEN item_count = 1
            THEN 'Single-item order'

        ELSE 'Multi-item order'
    END AS order_type,

    COUNT(*) AS order_count

FROM items_per_order

GROUP BY
    CASE
        WHEN item_count = 1
            THEN 'Single-item order'

        ELSE 'Multi-item order'
    END

ORDER BY order_count DESC;


/* ------------------------------------------------------------
   5.6 Identify orders containing multiple product categories
   ------------------------------------------------------------ */

SELECT
    order_id,
    COUNT(DISTINCT p.product_category_name)
        AS category_count
FROM olist.order_items AS oi
INNER JOIN olist.products AS p
    ON oi.product_id = p.product_id
GROUP BY order_id
HAVING COUNT(DISTINCT p.product_category_name) > 1
ORDER BY category_count DESC;


/* ------------------------------------------------------------
   5.7 Average review score by product category

   Uses DISTINCT order/category combinations so that orders
   containing multiple items in the same category do not
   receive additional weight.
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
),

order_category AS (
    SELECT DISTINCT
        oi.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS product_category

    FROM olist.order_items AS oi

    INNER JOIN olist.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.category_translation AS ct
        ON p.product_category_name
           = ct.product_category_name
)

SELECT
    oc.product_category,

    COUNT(DISTINCT oc.order_id)
        AS reviewed_orders,

    ROUND(
        AVG(r.average_review_score),
        2
    ) AS average_review_score

FROM order_category AS oc

INNER JOIN order_reviews AS r
    ON oc.order_id = r.order_id

GROUP BY oc.product_category

HAVING COUNT(DISTINCT oc.order_id) >= 100

ORDER BY average_review_score DESC;


/* ------------------------------------------------------------
   5.8 Delivery performance by product category
   ------------------------------------------------------------ */

WITH order_category AS (
    SELECT DISTINCT
        oi.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS product_category

    FROM olist.order_items AS oi

    INNER JOIN olist.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.category_translation AS ct
        ON p.product_category_name
           = ct.product_category_name
),

delivery_status AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_performance

    FROM olist.orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    oc.product_category,

    COUNT(DISTINCT d.order_id)
        AS delivered_orders,

    COUNT(DISTINCT d.order_id) FILTER (
        WHERE d.delivery_performance = 'On Time'
    ) AS on_time_orders,

    COUNT(DISTINCT d.order_id) FILTER (
        WHERE d.delivery_performance = 'Late'
    ) AS late_orders,

    ROUND(
        COUNT(DISTINCT d.order_id) FILTER (
            WHERE d.delivery_performance = 'On Time'
        ) * 100.0
        / COUNT(DISTINCT d.order_id),
        2
    ) AS on_time_percentage

FROM order_category AS oc

INNER JOIN delivery_status AS d
    ON oc.order_id = d.order_id

GROUP BY oc.product_category

HAVING COUNT(DISTINCT d.order_id) >= 100

ORDER BY on_time_percentage DESC;


/* ------------------------------------------------------------
   5.9 Combined category delivery + customer satisfaction

   This is the primary category-level analysis used to compare
   delivery performance and review scores together.
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
),

order_category AS (
    SELECT DISTINCT
        oi.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS product_category

    FROM olist.order_items AS oi

    INNER JOIN olist.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.category_translation AS ct
        ON p.product_category_name
           = ct.product_category_name
),

delivery_status AS (
    SELECT
        order_id,

        CASE
            WHEN order_delivered_customer_date
                 <= order_estimated_delivery_date
                THEN 'On Time'

            ELSE 'Late'
        END AS delivery_performance

    FROM olist.orders

    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    oc.product_category,

    COUNT(DISTINCT d.order_id)
        AS delivered_orders,

    ROUND(
        COUNT(DISTINCT d.order_id) FILTER (
            WHERE d.delivery_performance = 'On Time'
        ) * 100.0
        / COUNT(DISTINCT d.order_id),
        2
    ) AS on_time_percentage,

    ROUND(
        AVG(r.average_review_score),
        2
    ) AS average_review_score

FROM order_category AS oc

INNER JOIN delivery_status AS d
    ON oc.order_id = d.order_id

LEFT JOIN order_reviews AS r
    ON oc.order_id = r.order_id

GROUP BY oc.product_category

HAVING COUNT(DISTINCT d.order_id) >= 100

ORDER BY delivered_orders DESC;


/* ============================================================
   SECTION 6: TIME-BASED ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   6.1 Order volume by month
   ------------------------------------------------------------ */

SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    ) AS order_month,

    COUNT(*) AS order_count

FROM olist.orders

GROUP BY
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )

ORDER BY order_month;


/* ------------------------------------------------------------
   6.2 Monthly delivery performance
   ------------------------------------------------------------ */

SELECT
    DATE_TRUNC(
        'month',
        order_delivered_customer_date
    ) AS delivery_month,

    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              <= order_estimated_delivery_date
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  <= order_estimated_delivery_date
        ) * 100.0
        / COUNT(*),
        2
    ) AS on_time_percentage

FROM olist.orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL

GROUP BY
    DATE_TRUNC(
        'month',
        order_delivered_customer_date
    )

ORDER BY delivery_month;


/* ------------------------------------------------------------
   6.3 Monthly average review score
   ------------------------------------------------------------ */

WITH order_reviews AS (
    SELECT
        order_id,
        AVG(review_score) AS average_review_score
    FROM olist.reviews
    GROUP BY order_id
)

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    ) AS order_month,

    COUNT(DISTINCT o.order_id)
        AS reviewed_orders,

    ROUND(
        AVG(r.average_review_score),
        2
    ) AS average_review_score

FROM olist.orders AS o

INNER JOIN order_reviews AS r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )

ORDER BY order_month;


/* ============================================================
   SECTION 7: SELLER ANALYSIS
   ============================================================ */


/* ------------------------------------------------------------
   7.1 Seller order concentration

   Shows how much of total order volume is represented by
   individual sellers.
   ------------------------------------------------------------ */

WITH seller_orders AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist.order_items
    GROUP BY seller_id
),

total_orders AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_order_count
    FROM olist.order_items
)

SELECT
    s.seller_id,

    s.order_count,

    ROUND(
        s.order_count * 100.0
        / t.total_order_count,
        2
    ) AS order_share_percentage

FROM seller_orders AS s

CROSS JOIN total_orders AS t

ORDER BY s.order_count DESC;


/* ------------------------------------------------------------
   7.2 Top sellers and cumulative order share
   ------------------------------------------------------------ */

WITH seller_orders AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist.order_items
    GROUP BY seller_id
),

seller_share AS (
    SELECT
        seller_id,
        order_count,

        ROUND(
            order_count * 100.0
            / SUM(order_count) OVER (),
            2
        ) AS order_share_percentage

    FROM seller_orders
)

SELECT
    seller_id,
    order_count,
    order_share_percentage

FROM seller_share

ORDER BY order_count DESC

LIMIT 20;


/* ------------------------------------------------------------
   7.3 Seller delivery performance

   Only sellers with at least 100 delivered orders are included
   so that very small seller samples do not dominate the analysis.
   ------------------------------------------------------------ */

SELECT
    oi.seller_id,

    COUNT(DISTINCT o.order_id)
        AS delivered_orders,

    COUNT(DISTINCT o.order_id) FILTER (
        WHERE o.order_delivered_customer_date
              <= o.order_estimated_delivery_date
    ) AS on_time_orders,

    ROUND(
        COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date
                  <= o.order_estimated_delivery_date
        ) * 100.0
        / COUNT(DISTINCT o.order_id),
        2
    ) AS on_time_percentage

FROM olist.order_items AS oi

INNER JOIN olist.orders AS o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL

GROUP BY oi.seller_id

HAVING COUNT(DISTINCT o.order_id) >= 100

ORDER BY on_time_percentage DESC;


/* ============================================================
   SECTION 8: POWER BI DATASET DEVELOPMENT & QC
   ============================================================ */


/* ------------------------------------------------------------
   8.1 Reconcile delivered order counts
   ------------------------------------------------------------ */

SELECT
    COUNT(DISTINCT order_id) AS delivered_orders
FROM olist.orders
WHERE order_status = 'delivered';


/* ------------------------------------------------------------
   8.2 Reconcile delivered orders with product categories

   DISTINCT order/category combinations are used because an
   order may contain multiple products or categories.
   ------------------------------------------------------------ */

WITH order_category AS (
    SELECT DISTINCT
        oi.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS product_category

    FROM olist.order_items AS oi

    INNER JOIN olist.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.category_translation AS ct
        ON p.product_category_name
           = ct.product_category_name
)

SELECT
    COUNT(DISTINCT o.order_id)
        AS delivered_orders,

    COUNT(DISTINCT oc.order_id)
        AS delivered_orders_with_category,

    COUNT(DISTINCT o.order_id)
        - COUNT(DISTINCT oc.order_id)
        AS delivered_orders_without_category

FROM olist.orders AS o

LEFT JOIN order_category AS oc
    ON o.order_id = oc.order_id

WHERE o.order_status = 'delivered';


/* ------------------------------------------------------------
   8.3 Preview the final Power BI dataset

   The final Power BI view is created in Section 9.
   ------------------------------------------------------------ */

-- SELECT *
-- FROM olist.vw_powerbi_orders
-- LIMIT 100;


/* ============================================================
   SECTION 9: FINAL POWER BI VIEW
   ============================================================

   This view is the primary dataset used by Power BI.

   Design decisions:
   - Only delivered orders are included.
   - Multiple reviews for an order are averaged.
   - Orders can appear more than once when they contain
     multiple product categories.
   - Missing product categories are labeled "Uncategorized".
   - delay_band is added as the final column so the existing
     view columns remain in their original order.

   IMPORTANT:
   PostgreSQL allows CREATE OR REPLACE VIEW to add new columns
   at the END of an existing view. Do not insert delay_band
   between existing view columns.
   ============================================================ */


/* ------------------------------------------------------------
   9.1 Create or update the Power BI view
   ------------------------------------------------------------ */

CREATE OR REPLACE VIEW olist.vw_powerbi_orders AS

WITH order_reviews AS (

    /* Aggregate multiple review records to the order level */
    SELECT
        order_id,
        AVG(review_score) AS average_review_score

    FROM olist.reviews

    GROUP BY order_id
),

order_category AS (

    /* Create one row per unique order/category combination */
    SELECT DISTINCT
        oi.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Uncategorized'
        ) AS product_category

    FROM olist.order_items AS oi

    INNER JOIN olist.products AS p
        ON oi.product_id = p.product_id

    LEFT JOIN olist.category_translation AS ct
        ON p.product_category_name
           = ct.product_category_name
),

order_value AS (

    /* Calculate total item and freight value at the order level */
    SELECT
        order_id,

        SUM(price) AS order_value,

        SUM(freight_value) AS freight_value

    FROM olist.order_items

    GROUP BY order_id
)

SELECT

    /* --------------------------------------------------------
       Core order information
       -------------------------------------------------------- */

    o.order_id,

    o.order_purchase_timestamp,

    o.order_status,

    o.order_delivered_customer_date,

    o.order_estimated_delivery_date,


    /* --------------------------------------------------------
       Delivery difference

       Positive = delivered after estimated date
       Negative = delivered before estimated date
       -------------------------------------------------------- */

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL

        ELSE EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0
    END AS delivery_days_difference,


    /* --------------------------------------------------------
       Delivery performance classification
       -------------------------------------------------------- */

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL

        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On Time'

        ELSE 'Late'
    END AS delivery_performance,


    /* --------------------------------------------------------
       Customer satisfaction
       -------------------------------------------------------- */

    r.average_review_score,


    /* --------------------------------------------------------
       Product/category information
       -------------------------------------------------------- */

    oc.product_category,


    /* --------------------------------------------------------
       Order financial information
       -------------------------------------------------------- */

    ov.order_value,

    ov.freight_value,


    /* --------------------------------------------------------
       Delivery delay severity

       Only late orders receive a delay band.
       On-time orders receive NULL.

       This column is intentionally added at the END of the
       existing view so PostgreSQL can safely replace the view
       without changing existing column positions.
       -------------------------------------------------------- */

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL

        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN NULL

        WHEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 <= 2
            THEN '0–2 days'

        WHEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 <= 7
            THEN '3–7 days'

        WHEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 <= 14
            THEN '8–14 days'

        WHEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 <= 30
            THEN '15–30 days'

        ELSE '31+ days'

    END AS delay_band,
CASE
    WHEN o.order_delivered_customer_date IS NULL THEN NULL
    WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN NULL
    WHEN EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_estimated_delivery_date
        )
    ) / 86400.0 <= 2 THEN 1
    WHEN EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_estimated_delivery_date
        )
    ) / 86400.0 <= 7 THEN 2
    WHEN EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_estimated_delivery_date
        )
    ) / 86400.0 <= 14 THEN 3
    WHEN EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_estimated_delivery_date
        )
    ) / 86400.0 <= 30 THEN 4
    ELSE 5
END AS delay_band_sort

FROM olist.orders AS o

LEFT JOIN order_reviews AS r
    ON o.order_id = r.order_id

LEFT JOIN order_category AS oc
    ON o.order_id = oc.order_id

LEFT JOIN order_value AS ov
    ON o.order_id = ov.order_id

WHERE o.order_status = 'delivered';


/* ============================================================
   SECTION 10: FINAL POWER BI VIEW VALIDATION
   ============================================================ */


/* ------------------------------------------------------------
   10.1 Confirm the view row count
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS powerbi_view_rows
FROM olist.vw_powerbi_orders;


/* ------------------------------------------------------------
   10.2 Confirm the view columns
   ------------------------------------------------------------ */

SELECT
    ordinal_position,
    column_name,
    data_type

FROM information_schema.columns

WHERE table_schema = 'olist'
  AND table_name = 'vw_powerbi_orders'

ORDER BY ordinal_position;


/* ------------------------------------------------------------
   10.3 Confirm delay bands
   ------------------------------------------------------------ */

SELECT
    delay_band,
    COUNT(*) AS row_count

FROM olist.vw_powerbi_orders

GROUP BY delay_band

ORDER BY
    CASE
        WHEN delay_band = '0–2 days'
            THEN 1

        WHEN delay_band = '3–7 days'
            THEN 2

        WHEN delay_band = '8–14 days'
            THEN 3

        WHEN delay_band = '15–30 days'
            THEN 4

        WHEN delay_band = '31+ days'
            THEN 5

        ELSE 6
    END;


/* ------------------------------------------------------------
   10.4 Preview the final Power BI dataset
   ------------------------------------------------------------ */

SELECT *
FROM olist.vw_powerbi_orders
LIMIT 100;


/* ============================================================
   END OF OLIST E-COMMERCE ANALYSIS
   ============================================================ */