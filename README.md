# Metabase Scraping Analytics Dashboard

A self-contained analytics environment for monitoring and analyzing web scraping operations. Built with **Metabase**, **PostgreSQL**, and **Docker Compose**.

## What This Is

This project simulates a real-world scraping analytics pipeline. It sets up a PostgreSQL database populated with realistic web scraping data — proxy sessions, scrape jobs, product data, request logs, and price tracking — then connects it to Metabase for visualization and analysis.

The kind of questions this setup helps answer:

- Which target domains have the highest block rates, and what type of blocking are they using?
- How does proxy performance differ across residential vs. datacenter vs. ISP proxies?
- What percentage of scraped data is actually clean vs. garbage (captcha pages, partial data)?
- How are product prices trending over time across different retailers?
- Where are scrape failures concentrated — by geography, time of day, or proxy type?

## Architecture

```
┌──────────────┐       ┌──────────────────┐
│   Metabase   │──────▶│   PostgreSQL 16   │
│  (port 3000) │       │   (port 5432)     │
└──────────────┘       └──────────────────┘
                              │
                        ┌─────┴─────┐
                        │ Seed Data │
                        │ (5 tables │
                        │  5 views) │
                        └───────────┘
```

## Quick Start

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)

### Setup

```bash
git clone https://github.com/YOUR_USERNAME/metabase-scraping-analytics.git
cd metabase-scraping-analytics
docker compose up -d
```

Wait about 60 seconds for Metabase to initialize, then open [http://localhost:3000](http://localhost:3000).

### First-Time Metabase Setup

1. Open `http://localhost:3000`
2. Complete the setup wizard (create your admin account)
3. When prompted to add a database, use these credentials:
   - **Database type:** PostgreSQL
   - **Host:** postgres
   - **Port:** 5432
   - **Database name:** scraping_analytics
   - **Username:** metabase_reader
   - **Password:** metabase_read_2024

### Shutting Down

```bash
docker compose down          # stop containers (keeps data)
docker compose down -v       # stop and delete all data
```

## Database Schema

### Tables

| Table | Description | Key Fields |
|-------|-------------|------------|
| `proxy_sessions` | Individual proxy sessions | proxy_type, proxy_country, bandwidth_mb, status |
| `scrape_jobs` | Scraping tasks per domain | target_domain, success/fail counts, status |
| `scraped_products` | Extracted product data | price, rating, brand, data_quality |
| `request_log` | HTTP requests through proxy | http_status, response_time_ms, is_blocked, block_type |
| `price_history` | Daily price tracking for 10 products | product_name, domain, price over 90 days |

### Pre-Built Views

These views are ready to use in Metabase as saved questions or dashboard cards:

| View | What It Shows |
|------|---------------|
| `daily_success_rate` | Job success/failure trend by day |
| `domain_block_rate` | Which domains block the most, and how |
| `proxy_performance` | Success rate and throughput by proxy type and country |
| `data_quality_overview` | Clean vs. garbage data ratio over time |
| `price_volatility` | Price min/max/stddev per product across retailers |

## Suggested Dashboards

Once Metabase is running, try building these dashboards:

### 1. Operations Overview
- Daily success rate (line chart from `daily_success_rate`)
- Block rate by domain (bar chart from `domain_block_rate`)
- Active proxy sessions by country (map or bar chart)

### 2. Data Quality Monitor
- Clean vs. garbage data over time (stacked area from `data_quality_overview`)
- Top domains producing captcha pages
- Products with missing fields (filter `scraped_products` where `data_quality != 'clean'`)

### 3. Price Intelligence
- Price trends for tracked products (line chart from `price_history`)
- Most volatile products (table from `price_volatility`)
- Price comparison across retailers for the same product

### 4. Proxy Performance
- Success rate by proxy type (pie chart)
- Average response time by country (bar chart from `request_log`)
- Bandwidth consumption trends

## Customization

### Adding Your Own Data

Drop additional `.sql` files into `init-scripts/`. They run alphabetically on first startup.

### Connecting to the Database Directly

```bash
# Using psql
psql -h localhost -p 5432 -U scraper_admin -d scraping_analytics

# Or exec into the container
docker exec -it metabase-postgres psql -U scraper_admin -d scraping_analytics
```

### Resetting Everything

```bash
docker compose down -v
docker compose up -d
```

## Tech Stack

- **Metabase** (latest) — open source BI and analytics
- **PostgreSQL 16** — primary data store
- **Docker Compose** — orchestration

## License

MIT
