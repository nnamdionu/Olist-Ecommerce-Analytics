
-- =====================================================
-- PROJECT 04: OLIST E-COMMERCE ANALYSIS
-- =====================================================
-- Tool: PostgreSQL 18 | pgAdmin 4
-- Dataset: Brazilian E-Commerce Public Dataset (Olist)
-- Objective: Analyze sales performance, customer
-- behavior, order fulfillment, and delivery performance.
-- =====================================================

-- SECTION 1: ORDER VOLUME AND SALES TRENDS

-- 1.1 Monthly Order Trends

SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS order_month,
    COUNT(*) AS total_orders
FROM orders
GROUP BY
    EXTRACT(YEAR FROM order_purchase_timestamp),
    EXTRACT(MONTH FROM order_purchase_timestamp)
ORDER BY order_year, order_month;


-- 1.2 Year-over-Year Order Growth (January–August)

WITH yearly_orders AS (
    SELECT
        EXTRACT(YEAR FROM order_purchase_timestamp) AS order_year,
        COUNT(*) AS total_orders
    FROM orders
    WHERE EXTRACT(MONTH FROM order_purchase_timestamp)
          BETWEEN 1 AND 8
      AND EXTRACT(YEAR FROM order_purchase_timestamp)
          IN (2017, 2018)
    GROUP BY EXTRACT(YEAR FROM order_purchase_timestamp)
)
SELECT
    order_year,
    total_orders,
    LAG(total_orders) OVER (ORDER BY order_year) AS previous_year_orders,
    ROUND(
        100.0 * (
            total_orders - LAG(total_orders) OVER (ORDER BY order_year)
        ) / NULLIF(
            LAG(total_orders) OVER (ORDER BY order_year), 0
        ), 2
    ) AS yoy_growth_pct
FROM yearly_orders
ORDER BY order_year;

-- 1.3 Monthly Revenue Analysis

SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(p.payment_value)::NUMERIC, 2) AS total_revenue
FROM orders o
INNER JOIN order_payments p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    EXTRACT(YEAR FROM o.order_purchase_timestamp),
    EXTRACT(MONTH FROM o.order_purchase_timestamp)
ORDER BY order_year, order_month;

-- 1.4 Average Order Value (AOV) by Year

SELECT
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2) AS total_revenue,
    ROUND(
        SUM(p.payment_value)::NUMERIC /
        NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_order_value
FROM orders o
INNER JOIN order_payments p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY EXTRACT(YEAR FROM o.order_purchase_timestamp)
ORDER BY order_year;

-- 1.5 Year-over-Year Revenue Growth (January–August)

WITH yearly_revenue AS (
    SELECT
        EXTRACT(YEAR FROM o.order_purchase_timestamp) AS order_year,
        ROUND(SUM(p.payment_value)::NUMERIC, 2) AS total_revenue
    FROM orders o
    INNER JOIN order_payments p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
      AND EXTRACT(MONTH FROM o.order_purchase_timestamp)
          BETWEEN 1 AND 8
      AND EXTRACT(YEAR FROM o.order_purchase_timestamp)
          IN (2017, 2018)
    GROUP BY EXTRACT(YEAR FROM o.order_purchase_timestamp)
)
SELECT
    order_year,
    total_revenue,
    LAG(total_revenue) OVER (
        ORDER BY order_year
    ) AS previous_year_revenue,
    ROUND(
        100.0 * (
            total_revenue -
            LAG(total_revenue) OVER (ORDER BY order_year)
        ) /
        NULLIF(
            LAG(total_revenue) OVER (ORDER BY order_year),
            0
        ),
        2
    ) AS yoy_revenue_growth_pct
FROM yearly_revenue
ORDER BY order_year;

-- ============================================
-- SECTION 2: CUSTOMER ANALYSIS
-- ============================================

-- 2.1 Customer Distribution by State

SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers
GROUP BY customer_state
ORDER BY total_customers DESC;

-- 2.2 Top 10 Cities by Unique Customers

SELECT
    customer_city,
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers
GROUP BY customer_city, customer_state
ORDER BY total_customers DESC
LIMIT 10;

-- 2.3 Repeat Customer Analysis

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY total_orders DESC;

-- 2.4 Repeat Customer Rate

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (
        WHERE total_orders > 1
    ) AS repeat_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE total_orders > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_rate_pct
FROM customer_orders;

-- 2.5 Customer Order Frequency

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    INNER JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    total_orders,
    COUNT(*) AS number_of_customers
FROM customer_orders
GROUP BY total_orders
ORDER BY total_orders;

-- ============================================
-- SECTION 3: ORDER FULFILMENT AND DELIVERY
-- ============================================

-- 3.1 On-Time vs. Late Deliveries

SELECT
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY total_orders DESC;

-- 3.2 Average Delivery Time in Days

SELECT
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )) / 86400
        )::NUMERIC,
        2
    ) AS avg_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

  -- 3.3 Average Delivery Time by State

SELECT
    c.customer_state,
    COUNT(*) AS total_delivered_orders,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )) / 86400
        )::NUMERIC,
        2
    ) AS avg_delivery_days
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;

-- 3.4 On-Time Delivery Rate by State

SELECT
    c.customer_state,
    COUNT(*) AS total_delivered_orders,
    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date
              <= o.order_estimated_delivery_date
    ) AS on_time_orders,
    COUNT(*) FILTER (
        WHERE o.order_delivered_customer_date
              > o.order_estimated_delivery_date
    ) AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  <= o.order_estimated_delivery_date
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS on_time_rate_pct
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY on_time_rate_pct ASC;

-- 3.5 Average Delivery Delay for Late Orders

SELECT
    c.customer_state,
    COUNT(*) AS total_late_orders,
    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )) / 86400
        )::NUMERIC,
        2
    ) AS avg_delay_days
FROM orders o
INNER JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date
        > o.order_estimated_delivery_date
GROUP BY c.customer_state
ORDER BY avg_delay_days DESC;

-- ============================================
-- SECTION 4: CUSTOMER REVIEWS AND SATISFACTION
-- ============================================

-- 4.1 Distribution of Customer Review Scores

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_reviews
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- 4.2 Average Review Score by Delivery Performance

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY avg_review_score DESC;

-- 4.3 Average Review Score by State

SELECT
    c.customer_state,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM customers c
INNER JOIN orders o
    ON c.customer_id = o.customer_id
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
GROUP BY c.customer_state
ORDER BY avg_review_score ASC;

-- 4.4 Review Score Distribution by Delivery Status

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
        THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,
    r.review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY
                CASE
                    WHEN o.order_delivered_customer_date
                         <= o.order_estimated_delivery_date
                    THEN 'On Time'
                    ELSE 'Late'
                END
        ),
        2
    ) AS percentage_of_reviews
FROM orders o
INNER JOIN order_reviews r
    ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status, r.review_score
ORDER BY delivery_status, r.review_score DESC;


-- ============================================
-- SECTION 5: PAYMENT ANALYSIS
-- ============================================

-- 5.1 Payment Method Distribution

SELECT
    payment_type,
    COUNT(*) AS total_payment_records,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_payments,
    ROUND(
        SUM(payment_value)::NUMERIC,
        2
    ) AS total_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_records DESC;

-- 5.2 Average Payment Value by Payment Method

SELECT
    payment_type,
    COUNT(*) AS total_payment_records,
    ROUND(
        AVG(payment_value)::NUMERIC,
        2
    ) AS avg_payment_value,
    ROUND(
        MIN(payment_value)::NUMERIC,
        2
    ) AS min_payment_value,
    ROUND(
        MAX(payment_value)::NUMERIC,
        2
    ) AS max_payment_value
FROM order_payments
WHERE payment_type <> 'not_defined'
GROUP BY payment_type
ORDER BY avg_payment_value DESC;

-- 5.3 Credit Card Installment Analysis

SELECT
    payment_installments,
    COUNT(*) AS total_payments,
    ROUND(
        AVG(payment_value)::NUMERIC,
        2
    ) AS avg_payment_value,
    ROUND(
        SUM(payment_value)::NUMERIC,
        2
    ) AS total_payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;

-- 5.4 Payment Method by Order Status

SELECT
    o.order_status,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        SUM(p.payment_value)::NUMERIC,
        2
    ) AS total_payment_value
FROM orders o
INNER JOIN order_payments p
    ON o.order_id = p.order_id
GROUP BY
    o.order_status,
    p.payment_type
ORDER BY
    o.order_status,
    total_orders DESC;

	-- 5.5 Payment Installments and Order Value

WITH order_payment_summary AS (
    SELECT
        order_id,
        MAX(payment_installments) AS installments,
        SUM(payment_value) AS order_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    installments,
    COUNT(*) AS total_orders,
    ROUND(AVG(order_value)::NUMERIC, 2) AS avg_order_value,
    ROUND(SUM(order_value)::NUMERIC, 2) AS total_order_value
FROM order_payment_summary
WHERE installments > 0
GROUP BY installments
ORDER BY installments;

-- ==================================================
-- SECTION 6: PRODUCT AND CATEGORY PERFORMANCE
-- ==================================================

-- 6.1 Top 10 Product Categories by Revenue

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_revenue
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY product_category
ORDER BY total_revenue DESC
LIMIT 10;

-- 6.2 Top 10 Product Categories by Units Sold

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS total_items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_sales_value
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY product_category
ORDER BY total_items_sold DESC
LIMIT 10;

-- 6.3 Average Selling Price by Product Category

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS total_items_sold,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_selling_price,
    ROUND(MIN(oi.price)::NUMERIC, 2) AS min_selling_price,
    ROUND(MAX(oi.price)::NUMERIC, 2) AS max_selling_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY product_category
ORDER BY avg_selling_price DESC
LIMIT 10;

-- 6.4 Top 10 Best-Selling Individual Products

SELECT
    oi.product_id,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS total_items_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_sales_value,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_selling_price
FROM order_items oi
INNER JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
GROUP BY
    oi.product_id,
    product_category
ORDER BY total_items_sold DESC
LIMIT 10;

-- 6.5 Product Category Performance by Average Review Score

WITH category_reviews AS (
    SELECT DISTINCT
        oi.order_id,
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category
    FROM order_items oi
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    cr.product_category,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    COUNT(*) FILTER (
        WHERE r.review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE r.review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct
FROM category_reviews cr
INNER JOIN order_reviews r
    ON cr.order_id = r.order_id
GROUP BY cr.product_category
HAVING COUNT(*) >= 100
ORDER BY avg_review_score ASC;

-- 6.6 Product Categories with Highest Negative Review Rates

WITH category_reviews AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 p.product_category_name,
                 'Unknown') AS product_category,
        r.review_score
    FROM order_reviews r
    INNER JOIN order_items oi
        ON r.order_id = oi.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    product_category,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct
FROM category_reviews
GROUP BY product_category
HAVING COUNT(*) >= 100
ORDER BY negative_review_pct DESC
LIMIT 10;

-- 6.7 Validated Negative Review Rate by Product Category

WITH category_reviews AS (
    SELECT DISTINCT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        r.review_id,
        r.review_score
    FROM order_reviews r
    INNER JOIN order_items oi
        ON r.order_id = oi.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    product_category,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct
FROM category_reviews
GROUP BY product_category
HAVING COUNT(*) >= 100
ORDER BY negative_review_pct DESC
LIMIT 10;

-- 6.8 Product Categories with the Most Negative Reviews

WITH category_reviews AS (
    SELECT DISTINCT
        COALESCE(
            t.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        r.review_id,
        r.review_score
    FROM order_reviews r
    INNER JOIN order_items oi
        ON r.order_id = oi.order_id
    INNER JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_translation t
        ON p.product_category_name = t.product_category_name
)
SELECT
    product_category,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct,
    ROUND(AVG(review_score)::NUMERIC, 2)
        AS avg_review_score
FROM category_reviews
GROUP BY product_category
HAVING COUNT(*) >= 100
ORDER BY negative_reviews DESC
LIMIT 10;

-- 6.9 Monthly Customer Review Trends

SELECT
    EXTRACT(YEAR FROM review_creation_date) AS review_year,
    EXTRACT(MONTH FROM review_creation_date) AS review_month,
    COUNT(*) AS total_reviews,
    ROUND(
        AVG(review_score)::NUMERIC, 2
    ) AS avg_review_score,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct
FROM order_reviews
WHERE review_creation_date IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM review_creation_date),
    EXTRACT(MONTH FROM review_creation_date)
ORDER BY review_year, review_month;

-- 6.10 Monthly Delivery Performance and Customer Satisfaction

WITH monthly_performance AS (
    SELECT
        DATE_TRUNC(
            'month',
            r.review_creation_date
        )::DATE AS review_month,
        o.order_id,
        r.review_score,
        CASE
            WHEN o.order_delivered_customer_date >
                 o.order_estimated_delivery_date
            THEN 1
            ELSE 0
        END AS is_late
    FROM orders o
    INNER JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
        AND r.review_creation_date IS NOT NULL
)
SELECT
    review_month,
    COUNT(*) AS total_reviews,
    ROUND(
        AVG(review_score)::NUMERIC, 2
    ) AS avg_review_score,
    SUM(is_late) AS late_deliveries,
    ROUND(
        100.0 * SUM(is_late) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_pct,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct
FROM monthly_performance
GROUP BY review_month
ORDER BY review_month;


-- 6.11 Impact of Delivery Delays on Customer Satisfaction

WITH delivery_reviews AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
            THEN 'On Time'
            ELSE 'Late'
        END AS delivery_status,
        r.review_score
    FROM orders o
    INNER JOIN order_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    delivery_status,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct,
    ROUND(
        AVG(review_score)::NUMERIC,
        2
    ) AS avg_review_score
FROM delivery_reviews
GROUP BY delivery_status
ORDER BY negative_review_pct DESC;


-- ============================================
-- SECTION 7: SELLER PERFORMANCE ANALYSIS
-- ============================================

-- 7.1 Top 10 Sellers by Sales Value

SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS total_sales_value,
    ROUND(
        AVG(oi.price)::NUMERIC,
        2
    ) AS avg_item_price
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY total_sales_value DESC
LIMIT 10;


-- 7.2 Top 10 Sellers by Number of Orders

SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS total_sales_value,
    ROUND(
        SUM(oi.price)::NUMERIC /
        NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS avg_sales_per_order
FROM order_items oi
GROUP BY oi.seller_id
ORDER BY total_orders DESC
LIMIT 10;


-- 7.3 Top 10 Sellers by Average Sales per Order
-- Minimum 100 orders to focus on established sellers

SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_sales_value,
    ROUND(
        SUM(oi.price)::NUMERIC /
        NULLIF(COUNT(DISTINCT oi.order_id), 0),
        2
    ) AS avg_sales_per_order
FROM order_items oi
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) >= 100
ORDER BY avg_sales_per_order DESC
LIMIT 10;


-- 7.4 Top 10 Sellers by Average Customer Review Score
-- Minimum 100 reviews

SELECT
    oi.seller_id,
    COUNT(DISTINCT r.review_id) AS total_reviews,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
INNER JOIN order_reviews r
    ON oi.order_id = r.order_id
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT r.review_id) >= 100
ORDER BY avg_review_score DESC, total_reviews DESC
LIMIT 10;


-- 7.5 Top 10 Sellers by Negative Review Rate
-- Negative reviews = 1 or 2 stars
-- Minimum 100 reviews

WITH seller_reviews AS (
    SELECT DISTINCT
        oi.seller_id,
        r.review_id,
        r.review_score
    FROM order_items oi
    INNER JOIN order_reviews r
        ON oi.order_id = r.order_id
)
SELECT
    seller_id,
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct,
    ROUND(AVG(review_score)::NUMERIC, 2)
        AS avg_review_score
FROM seller_reviews
GROUP BY seller_id
HAVING COUNT(*) >= 100
ORDER BY negative_review_pct DESC
LIMIT 10;


-- 7.6 Top 10 Sellers by Late Delivery Rate
-- Minimum 100 delivered orders

WITH seller_deliveries AS (
    SELECT DISTINCT
        oi.seller_id,
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    seller_id,
    COUNT(*) AS total_delivered_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date >
              order_estimated_delivery_date
    ) AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date >
                  order_estimated_delivery_date
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_pct
FROM seller_deliveries
GROUP BY seller_id
HAVING COUNT(*) >= 100
ORDER BY late_delivery_pct DESC, total_delivered_orders DESC
LIMIT 10;


-- 7.7 Seller Delivery Performance vs Customer Reviews
-- Minimum 100 delivered orders and 100 reviews

WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
seller_performance AS (
    SELECT
        seller_id,
        COUNT(*) AS total_delivered_orders,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE order_delivered_customer_date >
                      order_estimated_delivery_date
            ) / COUNT(*),
            2
        ) AS late_delivery_pct
    FROM seller_orders
    GROUP BY seller_id
),
seller_reviews AS (
    SELECT DISTINCT
        so.seller_id,
        r.review_id,
        r.review_score
    FROM seller_orders so
    INNER JOIN order_reviews r
        ON so.order_id = r.order_id
),
review_performance AS (
    SELECT
        seller_id,
        COUNT(*) AS total_reviews,
        ROUND(AVG(review_score)::NUMERIC, 2)
            AS avg_review_score,
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE review_score <= 2
            ) / COUNT(*),
            2
        ) AS negative_review_pct
    FROM seller_reviews
    GROUP BY seller_id
)
SELECT
    sp.seller_id,
    sp.total_delivered_orders,
    sp.late_delivery_pct,
    rp.total_reviews,
    rp.avg_review_score,
    rp.negative_review_pct
FROM seller_performance sp
INNER JOIN review_performance rp
    ON sp.seller_id = rp.seller_id
WHERE sp.total_delivered_orders >= 100
    AND rp.total_reviews >= 100
ORDER BY sp.late_delivery_pct DESC
LIMIT 20;


-- 7.8 Correlation Between Late Deliveries and Negative Reviews
-- Minimum 100 delivered orders and 100 reviews per seller

WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        o.order_id,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM order_items oi
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
seller_delivery AS (
    SELECT
        seller_id,
        COUNT(*) AS total_delivered_orders,
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date >
                  order_estimated_delivery_date
        ) / COUNT(*) AS late_delivery_pct
    FROM seller_orders
    GROUP BY seller_id
),
seller_reviews AS (
    SELECT DISTINCT
        so.seller_id,
        r.review_id,
        r.review_score
    FROM seller_orders so
    INNER JOIN order_reviews r
        ON so.order_id = r.order_id
),
seller_review_metrics AS (
    SELECT
        seller_id,
        COUNT(*) AS total_reviews,
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / COUNT(*) AS negative_review_pct
    FROM seller_reviews
    GROUP BY seller_id
)
SELECT
    COUNT(*) AS total_sellers,
    ROUND(
        CORR(
            sd.late_delivery_pct,
            sr.negative_review_pct
        )::NUMERIC,
        4
    ) AS correlation_coefficient
FROM seller_delivery sd
INNER JOIN seller_review_metrics sr
    ON sd.seller_id = sr.seller_id
WHERE sd.total_delivered_orders >= 100
    AND sr.total_reviews >= 100; 

	-- ============================================
-- SECTION 8: EXECUTIVE KPI SUMMARY
-- ============================================

-- 8.1 Overall Business Performance

WITH order_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE o.order_status = 'delivered'
    ) AS delivered_orders,
    COUNT(DISTINCT o.customer_id) AS total_customer_records,
    ROUND(
        SUM(ot.order_value)::NUMERIC, 2
    ) AS total_payment_value,
    ROUND(
        AVG(ot.order_value)::NUMERIC, 2
    ) AS avg_order_value
FROM orders o
LEFT JOIN order_totals ot
    ON o.order_id = ot.order_id;

	
-- 8.2 Customer and Repeat Purchase KPIs

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    INNER JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS unique_customers,
    COUNT(*) FILTER (
        WHERE total_orders > 1
    ) AS repeat_customers,
    COUNT(*) FILTER (
        WHERE total_orders = 1
    ) AS one_time_customers,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE total_orders > 1
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_pct,
    ROUND(
        AVG(total_orders)::NUMERIC, 2
    ) AS avg_orders_per_customer
FROM customer_orders;


-- 8.3 Overall Delivery Performance KPIs

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS delivery_completion_pct,

    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date >
              order_estimated_delivery_date
    ) AS late_deliveries,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date >
                  order_estimated_delivery_date
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE order_status = 'delivered'
                  AND order_delivered_customer_date IS NOT NULL
                  AND order_estimated_delivery_date IS NOT NULL
            ), 0
        ),
        2
    ) AS late_delivery_pct,

    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (
                order_delivered_customer_date -
                order_purchase_timestamp
            )) / 86400
        ) FILTER (
            WHERE order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL
              AND order_purchase_timestamp IS NOT NULL
        )::NUMERIC,
        2
    ) AS avg_delivery_days

FROM orders;


-- 8.4 Overall Customer Satisfaction KPIs

SELECT
    COUNT(*) AS total_reviews,

    ROUND(
        AVG(review_score)::NUMERIC, 2
    ) AS avg_review_score,

    COUNT(*) FILTER (
        WHERE review_score >= 4
    ) AS positive_reviews,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score >= 4
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS positive_review_pct,

    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_pct,

    COUNT(*) FILTER (
        WHERE review_score = 3
    ) AS neutral_reviews

FROM order_reviews;


-- 8.5 Financial and Sales Performance KPIs
-- Product sales exclude freight charges.
-- Payment value includes all recorded payment transactions.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS product_sales,
        SUM(freight_value) AS freight_charges,
        COUNT(*) AS items_sold
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id
)
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        COALESCE(SUM(it.product_sales), 0)::NUMERIC, 2
    ) AS total_product_sales,
    ROUND(
        COALESCE(SUM(it.freight_charges), 0)::NUMERIC, 2
    ) AS total_freight_charges,
    ROUND(
        COALESCE(SUM(pt.payment_value), 0)::NUMERIC, 2
    ) AS total_payment_value,
    ROUND(
        AVG(pt.payment_value)::NUMERIC, 2
    ) AS avg_order_value,
    COALESCE(SUM(it.items_sold), 0) AS total_items_sold,
    ROUND(
        AVG(it.items_sold)::NUMERIC, 2
    ) AS avg_items_per_order
FROM orders o
LEFT JOIN item_totals it
    ON o.order_id = it.order_id
LEFT JOIN payment_totals pt
    ON o.order_id = pt.order_id;

-- ================================================
-- SECTION 9: DATA VALIDATION AND QUALITY CHECKS
-- ================================================

-- 9.1 Check for Duplicate Primary Identifiers

SELECT
    'orders' AS table_name,
    COUNT(*) AS total_records,
    COUNT(DISTINCT order_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_ids
FROM orders

UNION ALL

SELECT
    'customers',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM customers

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM sellers;

-- 9.2 Check for Missing Values in Orders

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE order_status IS NULL
    ) AS missing_order_status,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS missing_purchase_date,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_date,

    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS missing_estimated_delivery_date

FROM orders;

-- 9.3 Investigate Missing Delivery Dates by Order Status

SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_delivery_dates,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_delivery_pct
FROM orders
GROUP BY order_status
ORDER BY missing_delivery_dates DESC;

-- 9.4 Validate Relationships Between Tables

SELECT
    'Orders without matching customers' AS validation_check,
    COUNT(*) AS unmatched_records
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'Order items without matching orders',
    COUNT(*)
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'Order items without matching products',
    COUNT(*)
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'Order items without matching sellers',
    COUNT(*)
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL; 



	
