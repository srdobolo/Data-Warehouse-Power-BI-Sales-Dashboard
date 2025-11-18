USE [CeramicsWorldDB];
GO

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   Remove fact / calc tables to avoid FK conflicts before rebuilding dims
--------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.FACT_EXP_PT;
DROP TABLE IF EXISTS dbo.CALC_EXP_PT_2024;
DROP TABLE IF EXISTS dbo.FACT_EXP;
DROP TABLE IF EXISTS dbo.CALC_EXP_2024;
DROP TABLE IF EXISTS dbo.CALC_EXP_WORLD;
DROP TABLE IF EXISTS dbo.CALC_IMP_2024;
DROP TABLE IF EXISTS dbo.CALC_ALL_EXP_2024;
DROP TABLE IF EXISTS dbo.FACT_EXP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.CALC_EXP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_EXP_SECTOR_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_IMP_PT;
DROP TABLE IF EXISTS dbo.CALC_IMP_PT_2024;
DROP TABLE IF EXISTS dbo.CALC_IMP_CER_2024;
DROP TABLE IF EXISTS dbo.FACT_IMP_PROD;
DROP TABLE IF EXISTS dbo.CALC_IMP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_IMP_SECTOR;
DROP TABLE IF EXISTS dbo.FACT_IMP;
DROP TABLE IF EXISTS dbo.FACT_CONSTRUCTION;
DROP TABLE IF EXISTS dbo.FACT_PIB;
DROP TABLE IF EXISTS dbo.FACT_URBAN;

/* Legacy tables from previous iterations */
DROP TABLE IF EXISTS dbo.FACT_EXPORTACAO;
DROP TABLE IF EXISTS dbo.FACT_IMPORTACAO;
DROP TABLE IF EXISTS dbo.FACT_SERVICO_CONSTRUCAO;
DROP TABLE IF EXISTS dbo.FACT_PIB_PER_CAPITA;
DROP TABLE IF EXISTS dbo.FACT_POPULACAO_URBANA;
GO

/* ---------------------------------------------------------------------------
   Drop & recreate dimensions with final column names
--------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.DIM_COUNTRY;
DROP TABLE IF EXISTS dbo.DIM_PRODUCT;
DROP TABLE IF EXISTS dbo.DIM_DATE;

CREATE TABLE dbo.DIM_COUNTRY (
    id_country   INT IDENTITY(1,1) PRIMARY KEY,
    country_name VARCHAR(150) NOT NULL,
    country_code CHAR(3)      NOT NULL,
    CONSTRAINT UQ_DIM_COUNTRY_CODE UNIQUE (country_code),
    CONSTRAINT UQ_DIM_COUNTRY_NAME UNIQUE (country_name)
);

CREATE TABLE dbo.DIM_PRODUCT (
    id_product   INT IDENTITY(1,1) PRIMARY KEY,
    code         VARCHAR(20) NOT NULL,
    product_label VARCHAR(255) NULL,
    CONSTRAINT UQ_DIM_PRODUCT_CODE UNIQUE (code)
);

CREATE TABLE dbo.DIM_DATE (
    id_date INT IDENTITY(1,1) PRIMARY KEY,
    [year]  INT NOT NULL,
    [quarter] CHAR(2) NOT NULL,
    decade VARCHAR(10) NOT NULL,
    CONSTRAINT UQ_DIM_DATE UNIQUE ([year], [quarter])
);
GO

/* ---------------------------------------------------------------------------
   Populate DIM_COUNTRY
--------------------------------------------------------------------------- */
WITH country_sources AS (
    SELECT CountryName, ISO3 FROM staging.vw_exports_country_timeseries
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_imports_country_timeseries
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_world_exports_timeseries
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_world_imports_timeseries
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_imports_country_segment_timeseries
    UNION
    SELECT CountryName, CountryCode AS ISO3 FROM staging.vw_gdp_per_capita_timeseries
    UNION
    SELECT CountryName, CountryCode AS ISO3 FROM staging.vw_urban_population_timeseries
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_calc_exp_pt_2024
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_calc_exp_world_2024
    UNION
    SELECT CountryName, ISO3 FROM staging.vw_calc_imp_pt_2024
),
dedup_iso AS (
    SELECT
        ISO3,
        CountryName,
        ROW_NUMBER() OVER (
            PARTITION BY ISO3
            ORDER BY CASE WHEN CountryName IS NULL THEN 1 ELSE 0 END,
                     CountryName
        ) AS rn_iso
    FROM country_sources
    WHERE ISO3 IS NOT NULL
),
primary_names AS (
    SELECT
        ISO3,
        CASE
            WHEN CountryName IS NULL THEN CONCAT('ISO-', ISO3)
            ELSE CountryName
        END AS CountryLabel
    FROM dedup_iso
    WHERE rn_iso = 1
),
resolved AS (
    SELECT
        ISO3,
        CountryLabel,
        ROW_NUMBER() OVER (
            PARTITION BY CountryLabel
            ORDER BY ISO3
        ) AS rn_name
    FROM primary_names
)
INSERT INTO dbo.DIM_COUNTRY (country_name, country_code)
SELECT
    CASE WHEN rn_name > 1 THEN CONCAT(CountryLabel, ' (', ISO3, ')') ELSE CountryLabel END,
    ISO3
FROM resolved
ORDER BY CountryLabel;
GO

/* ---------------------------------------------------------------------------
   Populate DIM_PRODUCT
--------------------------------------------------------------------------- */
WITH product_sources AS (
    SELECT HSCode, ProductLabel FROM staging.vw_exports_products_timeseries
    UNION
    SELECT HSCode, ProductLabel FROM staging.vw_imports_products_timeseries
    UNION
    SELECT HSCode, ProductLabel FROM staging.vw_calc_exp_prod_pt_2024
    UNION
    SELECT HSCode, ProductLabel FROM staging.vw_calc_imp_prod_pt_2024
    UNION
    SELECT HSCode, ProductLabel FROM staging.vw_imports_country_segment_timeseries
),
normalized AS (
    SELECT
        UPPER(LTRIM(RTRIM(REPLACE(HSCode, '''', '')))) AS HSCode,
        LTRIM(RTRIM(ProductLabel)) AS ProductLabel
    FROM product_sources
    WHERE HSCode IS NOT NULL AND HSCode <> ''
),
ranked AS (
    SELECT
        HSCode,
        ProductLabel,
        ROW_NUMBER() OVER (
            PARTITION BY HSCode
            ORDER BY CASE WHEN ProductLabel IS NULL THEN 1 ELSE 0 END,
                     LEN(ProductLabel) DESC
        ) AS rn
    FROM normalized
)
INSERT INTO dbo.DIM_PRODUCT (code, product_label)
SELECT HSCode, ProductLabel
FROM ranked
WHERE rn = 1;
GO

/* ---------------------------------------------------------------------------
   Populate DIM_DATE
--------------------------------------------------------------------------- */
WITH year_list AS (
    SELECT DISTINCT Ano AS YearValue FROM staging.vw_exports_country_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_imports_country_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_world_exports_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_world_imports_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_exports_products_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_imports_products_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_gdp_per_capita_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_urban_population_timeseries
    UNION SELECT DISTINCT Ano FROM staging.vw_exports_services_quarterly
    UNION SELECT DISTINCT Ano FROM staging.vw_imports_services_quarterly
),
quarters AS (
    SELECT 'Q1' AS q UNION ALL
    SELECT 'Q2' UNION ALL
    SELECT 'Q3' UNION ALL
    SELECT 'Q4'
)
INSERT INTO dbo.DIM_DATE ([year], [quarter], decade)
SELECT
    y.YearValue,
    q.q,
    CONCAT((y.YearValue / 10) * 10, 's') AS decade
FROM year_list AS y
CROSS JOIN quarters AS q
ORDER BY y.YearValue, q.q;
GO
