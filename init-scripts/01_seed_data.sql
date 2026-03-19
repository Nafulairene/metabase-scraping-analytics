-- ============================================================
-- Scraping Analytics Database
-- Simulates a company using proxies to scrape e-commerce data
-- and analyzing results in Metabase
-- ============================================================

-- 1. PROXY SESSIONS: tracks each proxy session used for scraping
CREATE TABLE proxy_sessions (
    id SERIAL PRIMARY KEY,
    session_id UUID DEFAULT gen_random_uuid(),
    proxy_type VARCHAR(20) NOT NULL,        -- 'residential', 'datacenter', 'isp'
    proxy_country VARCHAR(3) NOT NULL,       -- ISO country code
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    requests_made INTEGER DEFAULT 0,
    bandwidth_mb NUMERIC(10,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active'      -- 'active', 'completed', 'failed', 'rate_limited'
);

-- 2. SCRAPE JOBS: each scraping task targeting a specific domain
CREATE TABLE scrape_jobs (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(200) NOT NULL,
    target_domain VARCHAR(255) NOT NULL,
    target_category VARCHAR(100),            -- 'electronics', 'fashion', 'groceries', etc.
    proxy_type VARCHAR(20) NOT NULL,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    total_pages INTEGER DEFAULT 0,
    successful_pages INTEGER DEFAULT 0,
    failed_pages INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'running',    -- 'running', 'completed', 'failed', 'partial'
    error_summary TEXT
);

-- 3. SCRAPED PRODUCTS: the actual data extracted from target sites
CREATE TABLE scraped_products (
    id SERIAL PRIMARY KEY,
    scrape_job_id INTEGER REFERENCES scrape_jobs(id),
    product_name VARCHAR(500),
    brand VARCHAR(200),
    price NUMERIC(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    original_price NUMERIC(10,2),            -- before discount
    rating NUMERIC(3,2),
    review_count INTEGER,
    in_stock BOOLEAN DEFAULT true,
    category VARCHAR(100),
    source_url TEXT,
    scraped_at TIMESTAMP NOT NULL,
    data_quality VARCHAR(20) DEFAULT 'clean' -- 'clean', 'partial', 'garbage', 'captcha_page'
);

-- 4. REQUEST LOG: individual HTTP requests through the proxy
CREATE TABLE request_log (
    id SERIAL PRIMARY KEY,
    proxy_session_id INTEGER REFERENCES proxy_sessions(id),
    scrape_job_id INTEGER REFERENCES scrape_jobs(id),
    request_url TEXT,
    http_status INTEGER,
    response_time_ms INTEGER,
    response_size_bytes INTEGER,
    proxy_country VARCHAR(3),
    is_blocked BOOLEAN DEFAULT false,
    block_type VARCHAR(50),                  -- 'captcha', 'access_denied', 'rate_limit', 'geo_block'
    requested_at TIMESTAMP NOT NULL
);

-- 5. PRICE HISTORY: tracks price changes over time for monitored products
CREATE TABLE price_history (
    id SERIAL PRIMARY KEY,
    product_external_id VARCHAR(100),        -- the product ID on the target site
    product_name VARCHAR(500),
    domain VARCHAR(255),
    price NUMERIC(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    recorded_at TIMESTAMP NOT NULL
);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Generate proxy sessions over the last 90 days
INSERT INTO proxy_sessions (proxy_type, proxy_country, started_at, ended_at, requests_made, bandwidth_mb, status)
SELECT
    (ARRAY['residential', 'datacenter', 'isp'])[1 + floor(random() * 3)],
    (ARRAY['US', 'GB', 'DE', 'FR', 'JP', 'BR', 'CA', 'AU', 'IN', 'KE'])[1 + floor(random() * 10)],
    ts,
    ts + (interval '1 minute' * (10 + floor(random() * 110))),
    (50 + floor(random() * 950))::integer,
    round((5 + random() * 195)::numeric, 2),
    (ARRAY['completed', 'completed', 'completed', 'completed', 'failed', 'rate_limited'])[1 + floor(random() * 6)]
FROM generate_series(
    NOW() - interval '90 days',
    NOW(),
    interval '15 minutes'
) AS ts
WHERE random() < 0.3;  -- ~30% of timeslots have sessions

-- Generate scrape jobs
INSERT INTO scrape_jobs (job_name, target_domain, target_category, proxy_type, started_at, completed_at, total_pages, successful_pages, failed_pages, status, error_summary)
SELECT
    'Job_' || to_char(ts, 'YYYYMMDD_HH24MI'),
    domain,
    category,
    (ARRAY['residential', 'datacenter', 'isp'])[1 + floor(random() * 3)],
    ts,
    ts + (interval '1 minute' * (5 + floor(random() * 55))),
    total,
    success,
    total - success,
    CASE
        WHEN (total - success)::float / total > 0.5 THEN 'failed'
        WHEN (total - success)::float / total > 0.1 THEN 'partial'
        ELSE 'completed'
    END,
    CASE
        WHEN (total - success)::float / total > 0.3 THEN 'High failure rate detected. Possible anti-bot measures on target.'
        ELSE NULL
    END
FROM (
    SELECT
        ts,
        (ARRAY['amazon.com', 'ebay.com', 'walmart.com', 'bestbuy.com', 'target.com',
               'newegg.com', 'aliexpress.com', 'etsy.com', 'wayfair.com', 'zappos.com'])[1 + floor(random() * 10)] AS domain,
        (ARRAY['electronics', 'fashion', 'home_garden', 'groceries', 'sports', 'toys', 'automotive', 'books'])[1 + floor(random() * 8)] AS category,
        (100 + floor(random() * 900))::integer AS total,
        (50 + floor(random() * 850))::integer AS success
    FROM generate_series(
        NOW() - interval '90 days',
        NOW(),
        interval '2 hours'
    ) AS ts
    WHERE random() < 0.4
) sub
WHERE success <= total;

-- Generate scraped products linked to jobs
INSERT INTO scraped_products (scrape_job_id, product_name, brand, price, currency, original_price, rating, review_count, in_stock, category, source_url, scraped_at, data_quality)
SELECT
    j.id,
    (ARRAY['Wireless Headphones', 'Running Shoes', 'Laptop Stand', 'Coffee Maker', 'Yoga Mat',
           'Bluetooth Speaker', 'Phone Case', 'Desk Lamp', 'Water Bottle', 'Backpack',
           'Smartwatch', 'Keyboard', 'Mouse Pad', 'Webcam', 'USB Hub',
           'Standing Desk', 'Monitor Arm', 'Cable Organizer', 'Power Bank', 'Fitness Tracker'])[1 + floor(random() * 20)]
    || ' ' || (ARRAY['Pro', 'Elite', 'Plus', 'Max', 'Lite', 'Ultra', 'Basic', 'Premium'])[1 + floor(random() * 8)]
    || ' ' || (1000 + floor(random() * 9000))::text,
    (ARRAY['Sony', 'Samsung', 'Apple', 'Anker', 'Bose', 'JBL', 'Nike', 'Adidas',
           'Dell', 'HP', 'Logitech', 'Corsair', 'HyperX', 'Razer', 'Belkin'])[1 + floor(random() * 15)],
    round((9.99 + random() * 490)::numeric, 2),
    'USD',
    CASE WHEN random() < 0.4 THEN round((19.99 + random() * 590)::numeric, 2) ELSE NULL END,
    round((1.0 + random() * 4.0)::numeric, 2),
    (floor(random() * 5000))::integer,
    random() > 0.15,
    j.target_category,
    'https://' || j.target_domain || '/product/' || md5(random()::text),
    j.started_at + (interval '1 second' * floor(random() * 3600)),
    (ARRAY['clean', 'clean', 'clean', 'clean', 'clean', 'partial', 'garbage', 'captcha_page'])[1 + floor(random() * 8)]
FROM scrape_jobs j
CROSS JOIN generate_series(1, 5)  -- ~5 products per job
WHERE random() < 0.7;

-- Generate request log entries
INSERT INTO request_log (proxy_session_id, scrape_job_id, request_url, http_status, response_time_ms, response_size_bytes, proxy_country, is_blocked, block_type, requested_at)
SELECT
    ps.id,
    j.id,
    'https://' || j.target_domain || '/page/' || floor(random() * 1000),
    status_code,
    (50 + floor(random() * 4950))::integer,
    (1024 + floor(random() * 512000))::integer,
    ps.proxy_country,
    status_code != 200,
    CASE
        WHEN status_code = 403 THEN 'access_denied'
        WHEN status_code = 429 THEN 'rate_limit'
        WHEN status_code = 503 THEN 'captcha'
        WHEN status_code = 451 THEN 'geo_block'
        ELSE NULL
    END,
    j.started_at + (interval '1 second' * floor(random() * 3600))
FROM proxy_sessions ps
CROSS JOIN LATERAL (
    SELECT id, target_domain, started_at
    FROM scrape_jobs
    ORDER BY random()
    LIMIT 1
) j
CROSS JOIN LATERAL (
    SELECT (ARRAY[200, 200, 200, 200, 200, 200, 200, 403, 429, 503, 451, 500])[1 + floor(random() * 12)] AS status_code
) sc
CROSS JOIN generate_series(1, 3)
WHERE random() < 0.5;

-- Generate price history for trending products
INSERT INTO price_history (product_external_id, product_name, domain, price, currency, recorded_at)
SELECT
    'PROD-' || product_num::text,
    product_name,
    domain,
    round((base_price + (random() * 50 - 25))::numeric, 2),
    'USD',
    day
FROM (
    SELECT
        n AS product_num,
        (ARRAY['Sony WH-1000XM5', 'MacBook Air M3', 'Samsung Galaxy S24', 'iPad Pro 12.9',
               'AirPods Pro 2', 'Dell XPS 15', 'Nintendo Switch OLED', 'Dyson V15',
               'Kindle Paperwhite', 'Bose QC Ultra'])[n] AS product_name,
        (ARRAY['amazon.com', 'bestbuy.com', 'walmart.com', 'newegg.com', 'target.com'])[1 + floor(random() * 5)] AS domain,
        (ARRAY[349.99, 1099.00, 799.99, 1099.00, 249.00, 1299.99, 349.99, 649.99, 139.99, 429.00])[n] AS base_price
    FROM generate_series(1, 10) AS n
) products
CROSS JOIN generate_series(NOW() - interval '90 days', NOW(), interval '1 day') AS day;

-- ============================================================
-- USEFUL VIEWS FOR METABASE DASHBOARDS
-- ============================================================

-- Daily scraping success rate
CREATE VIEW daily_success_rate AS
SELECT
    DATE(started_at) AS scrape_date,
    COUNT(*) AS total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') AS successful_jobs,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed_jobs,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / COUNT(*), 1) AS success_pct
FROM scrape_jobs
GROUP BY DATE(started_at)
ORDER BY scrape_date;

-- Block rate by domain
CREATE VIEW domain_block_rate AS
SELECT
    j.target_domain,
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (WHERE r.is_blocked) AS blocked_requests,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.is_blocked) / COUNT(*), 1) AS block_rate_pct,
    MODE() WITHIN GROUP (ORDER BY r.block_type) FILTER (WHERE r.block_type IS NOT NULL) AS most_common_block
FROM request_log r
JOIN scrape_jobs j ON j.id = r.scrape_job_id
GROUP BY j.target_domain
ORDER BY block_rate_pct DESC;

-- Proxy performance by type and country
CREATE VIEW proxy_performance AS
SELECT
    proxy_type,
    proxy_country,
    COUNT(*) AS total_sessions,
    ROUND(AVG(requests_made), 0) AS avg_requests,
    ROUND(AVG(bandwidth_mb), 2) AS avg_bandwidth_mb,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / COUNT(*), 1) AS success_pct
FROM proxy_sessions
GROUP BY proxy_type, proxy_country
ORDER BY proxy_type, success_pct DESC;

-- Data quality overview
CREATE VIEW data_quality_overview AS
SELECT
    DATE(scraped_at) AS scrape_date,
    COUNT(*) AS total_products,
    COUNT(*) FILTER (WHERE data_quality = 'clean') AS clean_count,
    COUNT(*) FILTER (WHERE data_quality = 'partial') AS partial_count,
    COUNT(*) FILTER (WHERE data_quality = 'garbage') AS garbage_count,
    COUNT(*) FILTER (WHERE data_quality = 'captcha_page') AS captcha_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE data_quality = 'clean') / COUNT(*), 1) AS clean_pct
FROM scraped_products
GROUP BY DATE(scraped_at)
ORDER BY scrape_date;

-- Price volatility tracker
CREATE VIEW price_volatility AS
SELECT
    product_name,
    domain,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(STDDEV(price), 2) AS price_stddev,
    COUNT(*) AS data_points
FROM price_history
GROUP BY product_name, domain
ORDER BY price_stddev DESC;

-- ============================================================
-- CREATE READ-ONLY USER FOR METABASE
-- ============================================================
CREATE USER metabase_reader WITH PASSWORD 'metabase_read_2024';
GRANT CONNECT ON DATABASE scraping_analytics TO metabase_reader;
GRANT USAGE ON SCHEMA public TO metabase_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase_reader;
