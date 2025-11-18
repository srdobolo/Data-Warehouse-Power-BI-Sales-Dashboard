USE [CeramicsWorldDB];
GO

SET NOCOUNT ON;

/* ---------------------------------------------------------------------------
   Drop existing fact / calc tables
--------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.FACT_EXP_PT;
DROP TABLE IF EXISTS dbo.CALC_EXP_PT_2024;
DROP TABLE IF EXISTS dbo.FACT_EXP;
DROP TABLE IF EXISTS dbo.CALC_EXP_2024;
DROP TABLE IF EXISTS dbo.CALC_EXP_WORLD;
DROP TABLE IF EXISTS dbo.CALC_IMP_CER_2024;
DROP TABLE IF EXISTS dbo.CALC_IMP_2024;
DROP TABLE IF EXISTS dbo.CALC_ALL_EXP_2024;
DROP TABLE IF EXISTS dbo.FACT_EXP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.CALC_EXP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_EXP_SECTOR_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_IMP_PT;
DROP TABLE IF EXISTS dbo.CALC_IMP_PT_2024;
DROP TABLE IF EXISTS dbo.FACT_IMP_PROD;
DROP TABLE IF EXISTS dbo.FACT_IMP_SEGMENT;
DROP TABLE IF EXISTS dbo.CALC_IMP_PROD_BY_PT;
DROP TABLE IF EXISTS dbo.FACT_IMP_SECTOR;
DROP TABLE IF EXISTS dbo.FACT_PIB;
DROP TABLE IF EXISTS dbo.FACT_URBAN;
DROP TABLE IF EXISTS dbo.FACT_IMP;
DROP TABLE IF EXISTS dbo.FACT_CONSTRUCTION;
GO

/* ---------------------------------------------------------------------------
   Create tables (dimensions already exist)
--------------------------------------------------------------------------- */
CREATE TABLE dbo.FACT_EXP_PT (
    id_exp_pt INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_EXP_PT_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_EXP_PT_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.CALC_EXP_PT_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    share_portugal_exports_pct DECIMAL(18,4) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    ranking_world_imports INT NULL,
    share_world_imports_pct DECIMAL(18,4) NULL,
    partner_growth_2020_2024_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    avg_tariff_pct DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_EXP_PT_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.FACT_EXP (
    id_exp INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_EXP_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_EXP_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.CALC_EXP_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_exports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_EXP_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.CALC_EXP_WORLD (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_exports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_EXP_WORLD_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.CALC_IMP_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_imports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_IMP_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.CALC_ALL_EXP_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_exports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_ALL_EXP_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.FACT_EXP_PROD_BY_PT (
    id_exp_prod_pt INT IDENTITY(1,1) PRIMARY KEY,
    id_product INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_EXP_PROD_PRODUCT FOREIGN KEY (id_product) REFERENCES dbo.DIM_PRODUCT(id_product),
    CONSTRAINT FK_FACT_EXP_PROD_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.CALC_EXP_PROD_BY_PT (
    id_product INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_quantity_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    world_import_growth_2020_2024_pct DECIMAL(18,4) NULL,
    share_world_exports_pct DECIMAL(18,4) NULL,
    ranking_world_exports INT NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_EXP_PROD_PRODUCT FOREIGN KEY (id_product) REFERENCES dbo.DIM_PRODUCT(id_product)
);

CREATE TABLE dbo.FACT_EXP_SECTOR_BY_PT (
    id_exp_sector INT IDENTITY(1,1) PRIMARY KEY,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_EXP_SECTOR_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_IMP_PT (
    id_imp_pt INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_IMP_PT_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_IMP_PT_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.CALC_IMP_PT_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_imports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    avg_tariff_pct DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_IMP_PT_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.CALC_IMP_CER_2024 (
    id_country INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    share_world_imports_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    avg_tariff_pct DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_IMP_CER_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country)
);

CREATE TABLE dbo.FACT_IMP_PROD (
    id_imp_prod INT IDENTITY(1,1) PRIMARY KEY,
    id_product INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_IMP_PROD_PRODUCT FOREIGN KEY (id_product) REFERENCES dbo.DIM_PRODUCT(id_product),
    CONSTRAINT FK_FACT_IMP_PROD_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.CALC_IMP_PROD_BY_PT (
    id_product INT PRIMARY KEY,
    value_2024_usd DECIMAL(18,2) NULL,
    trade_balance_2024_usd DECIMAL(18,2) NULL,
    growth_value_2020_2024_pct DECIMAL(18,4) NULL,
    growth_quantity_2020_2024_pct DECIMAL(18,4) NULL,
    growth_value_2023_2024_pct DECIMAL(18,4) NULL,
    world_export_growth_2020_2024_pct DECIMAL(18,4) NULL,
    avg_distance_km DECIMAL(18,2) NULL,
    concentration_index DECIMAL(18,4) NULL,
    CONSTRAINT FK_CALC_IMP_PROD_PRODUCT FOREIGN KEY (id_product) REFERENCES dbo.DIM_PRODUCT(id_product)
);

CREATE TABLE dbo.FACT_IMP_SECTOR (
    id_imp_sector INT IDENTITY(1,1) PRIMARY KEY,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_IMP_SECTOR_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_PIB (
    id_pib INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    gdp_per_capita_usd DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_PIB_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_PIB_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_URBAN (
    id_urban INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    urban_population_total DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_URBAN_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_URBAN_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_IMP (
    id_imp INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_IMP_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_IMP_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_IMP_SEGMENT (
    id_imp_segment INT IDENTITY(1,1) PRIMARY KEY,
    id_product INT NOT NULL,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value DECIMAL(18,2) NULL,
    CONSTRAINT FK_FACT_IMP_SEGMENT_PRODUCT FOREIGN KEY (id_product) REFERENCES dbo.DIM_PRODUCT(id_product),
    CONSTRAINT FK_FACT_IMP_SEGMENT_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_IMP_SEGMENT_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);

CREATE TABLE dbo.FACT_CONSTRUCTION (
    id_construction INT IDENTITY(1,1) PRIMARY KEY,
    id_country INT NOT NULL,
    id_date INT NOT NULL,
    value_added_growth_pct DECIMAL(18,4) NULL,
    CONSTRAINT FK_FACT_CONSTRUCTION_COUNTRY FOREIGN KEY (id_country) REFERENCES dbo.DIM_COUNTRY(id_country),
    CONSTRAINT FK_FACT_CONSTRUCTION_DATE FOREIGN KEY (id_date) REFERENCES dbo.DIM_DATE(id_date)
);
GO

/* ---------------------------------------------------------------------------
   FACT_EXP_PT (Portugal exports by destination)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_EXP_PT (id_country, id_date, value)
SELECT
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_exports_country_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   CALC_EXP_PT_2024
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_EXP_PT_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    share_portugal_exports_pct,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    ranking_world_imports,
    share_world_imports_pct,
    partner_growth_2020_2024_pct,
    avg_distance_km,
    concentration_index,
    avg_tariff_pct
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.SharePortugalExportsPct * 0.01,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.RankingWorldImports,
    src.ShareWorldImportsPct * 0.01,
    src.PartnerGrowth2020_2024_Pct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex,
    src.AvgTariffPct * 0.01
FROM staging.vw_calc_exp_pt_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   FACT_EXP (world exports by exporter)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_EXP (id_country, id_date, value)
SELECT
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_world_exports_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   CALC_EXP_2024
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_EXP_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_exports_pct,
    avg_distance_km,
    concentration_index
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldExportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_exp_world_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   CALC_ALL_EXP_2024 (all products)
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_ALL_EXP_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_exports_pct,
    avg_distance_km,
    concentration_index
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldExportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_all_exp_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   CALC_EXP_WORLD (all products snapshot)
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_EXP_WORLD (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_exports_pct,
    avg_distance_km,
    concentration_index
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldExportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_all_exp_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   CALC_IMP_2024 (ceramic importers snapshot - Trade Map)
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_IMP_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_imports_pct,
    avg_distance_km,
    concentration_index
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldImportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_imp_pt_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   FACT_EXP_PROD_BY_PT
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_EXP_PROD_BY_PT (id_product, id_date, value)
SELECT
    prod.id_product,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_exports_products_timeseries AS src
JOIN dbo.DIM_PRODUCT AS prod
    ON prod.code = src.HSCode
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   CALC_EXP_PROD_BY_PT
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_EXP_PROD_BY_PT (
    id_product,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_quantity_2020_2024_pct,
    growth_value_2023_2024_pct,
    world_import_growth_2020_2024_pct,
    share_world_exports_pct,
    ranking_world_exports,
    avg_distance_km,
    concentration_index
)
SELECT
    prod.id_product,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.GrowthValue2020_2024_Pct * 0.01,
    src.GrowthQty2020_2024_Pct * 0.01,
    src.GrowthValue2023_2024_Pct * 0.01,
    src.WorldImportGrowth2020_2024_Pct * 0.01,
    src.ShareWorldExportsPct * 0.01,
    src.RankingWorldExports,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_exp_prod_pt_2024 AS src
JOIN dbo.DIM_PRODUCT AS prod
    ON prod.code = src.HSCode;
GO

/* ---------------------------------------------------------------------------
   FACT_EXP_SECTOR_BY_PT (construction services exports)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_EXP_SECTOR_BY_PT (id_date, value)
SELECT
    date_map.id_date,
    svc.Valor_USD
FROM staging.vw_exports_services_quarterly AS svc
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = svc.Ano
   AND date_map.[quarter] = svc.Trimestre
WHERE svc.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   FACT_IMP_PT (world imports by importer)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_IMP_PT (id_country, id_date, value)
SELECT
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_world_imports_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   CALC_IMP_PT_2024
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_IMP_PT_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_imports_pct,
    avg_distance_km,
    concentration_index,
    avg_tariff_pct
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldImportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex,
    src.AvgTariffPct * 0.01
FROM staging.vw_calc_imp_pt_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   CALC_IMP_CER_2024 (ceramics importers snapshot)
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_IMP_CER_2024 (
    id_country,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_value_2023_2024_pct,
    share_world_imports_pct,
    avg_distance_km,
    concentration_index,
    avg_tariff_pct
)
SELECT
    country.id_country,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.Growth2020_2024_Pct * 0.01,
    src.Growth2023_2024_Pct * 0.01,
    src.ShareWorldImportsPct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex,
    src.AvgTariffPct * 0.01
FROM staging.vw_calc_imp_pt_2024 AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3;
GO

/* ---------------------------------------------------------------------------
   FACT_IMP (world imports by importer, annual)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_IMP (id_country, id_date, value)
SELECT
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_imports_country_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   FACT_IMP_SEGMENT (imports by importer for HS 6907/6908/6910, annual)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_IMP_SEGMENT (id_product, id_country, id_date, value)
SELECT
    prod.id_product,
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_imports_country_segment_timeseries AS src
JOIN dbo.DIM_PRODUCT AS prod
    ON prod.code = src.HSCode
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.ISO3
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   FACT_IMP_PROD (global imports by HS code, annual)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_IMP_PROD (id_product, id_date, value)
SELECT
    prod.id_product,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_imports_products_timeseries AS src
JOIN dbo.DIM_PRODUCT AS prod
    ON prod.code = src.HSCode
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   CALC_IMP_PROD_BY_PT
--------------------------------------------------------------------------- */
INSERT INTO dbo.CALC_IMP_PROD_BY_PT (
    id_product,
    value_2024_usd,
    trade_balance_2024_usd,
    growth_value_2020_2024_pct,
    growth_quantity_2020_2024_pct,
    growth_value_2023_2024_pct,
    world_export_growth_2020_2024_pct,
    avg_distance_km,
    concentration_index
)
SELECT
    prod.id_product,
    src.Value2024_USD,
    src.TradeBalance2024_USD,
    src.GrowthValue2020_2024_Pct * 0.01,
    src.GrowthQty2020_2024_Pct * 0.01,
    src.GrowthValue2023_2024_Pct * 0.01,
    src.WorldExportGrowth2020_2024_Pct * 0.01,
    src.AvgDistanceKm,
    src.ConcentrationIndex
FROM staging.vw_calc_imp_prod_pt_2024 AS src
JOIN dbo.DIM_PRODUCT AS prod
    ON prod.code = src.HSCode;
GO

/* ---------------------------------------------------------------------------
   FACT_IMP_SECTOR (construction services imports - world total)
--------------------------------------------------------------------------- */
;WITH svc AS (
    SELECT
        TRY_CONVERT(INT, LEFT(period.PeriodLabel, 4)) AS Ano,
        RIGHT(period.PeriodLabel, 2) AS Trimestre,
        TRY_CONVERT(DECIMAL(18, 2), period.Amount) AS Valor_USD
    FROM dbo.imports_services_csv_trade_map_list_of_importers_for_the_selected_service_construction_xls AS base
    CROSS APPLY (VALUES
        ('2019-Q1', [Imported value in 2019-Q1]),
        ('2019-Q2', [Imported value in 2019-Q2]),
        ('2019-Q3', [Imported value in 2019-Q3]),
        ('2019-Q4', [Imported value in 2019-Q4]),
        ('2020-Q1', [Imported value in 2020-Q1]),
        ('2020-Q2', [Imported value in 2020-Q2]),
        ('2020-Q3', [Imported value in 2020-Q3]),
        ('2020-Q4', [Imported value in 2020-Q4]),
        ('2021-Q1', [Imported value in 2021-Q1]),
        ('2021-Q2', [Imported value in 2021-Q2]),
        ('2021-Q3', [Imported value in 2021-Q3]),
        ('2021-Q4', [Imported value in 2021-Q4]),
        ('2022-Q1', [Imported value in 2022-Q1]),
        ('2022-Q2', [Imported value in 2022-Q2]),
        ('2022-Q3', [Imported value in 2022-Q3]),
        ('2022-Q4', [Imported value in 2022-Q4]),
        ('2023-Q1', [Imported value in 2023-Q1]),
        ('2023-Q2', [Imported value in 2023-Q2]),
        ('2023-Q3', [Imported value in 2023-Q3]),
        ('2023-Q4', [Imported value in 2023-Q4])
    ) AS period(PeriodLabel, Amount)
    WHERE period.Amount IS NOT NULL
)
INSERT INTO dbo.FACT_IMP_SECTOR (id_date, value)
SELECT
    date_map.id_date,
    SUM(svc.Valor_USD) AS value
FROM svc
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = svc.Ano
   AND date_map.[quarter] = svc.Trimestre
GROUP BY date_map.id_date;
GO

/* ---------------------------------------------------------------------------
   FACT_PIB (GDP per capita)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_PIB (id_country, id_date, gdp_per_capita_usd)
SELECT
    country.id_country,
    date_map.id_date,
    src.Valor_USD
FROM staging.vw_gdp_per_capita_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.CountryCode
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Valor_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   FACT_URBAN (urban population)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_URBAN (id_country, id_date, urban_population_total)
SELECT
    country.id_country,
    date_map.id_date,
    src.Total_Populacao
FROM staging.vw_urban_population_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.CountryCode
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.Total_Populacao IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   FACT_CONSTRUCTION (industry incl. construction growth)
--------------------------------------------------------------------------- */
INSERT INTO dbo.FACT_CONSTRUCTION (id_country, id_date, value_added_growth_pct)
SELECT
    country.id_country,
    date_map.id_date,
    src.GrowthPct
FROM staging.vw_industry_construction_growth_timeseries AS src
JOIN dbo.DIM_COUNTRY AS country
    ON country.country_code = src.CountryCode
JOIN dbo.DIM_DATE AS date_map
    ON date_map.[year] = src.Ano
   AND date_map.[quarter] = 'Q4'
WHERE src.GrowthPct IS NOT NULL;
GO
