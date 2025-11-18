USE [CeramicsWorldDB];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

/* ---------------------------------------------------------------------------
   Cleanup existing staging objects so the script can be rerun safely
--------------------------------------------------------------------------- */
IF OBJECT_ID('staging.vw_exports_country_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_exports_country_timeseries;
IF OBJECT_ID('staging.vw_imports_country_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_imports_country_timeseries;
IF OBJECT_ID('staging.vw_exports_products_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_exports_products_timeseries;
IF OBJECT_ID('staging.vw_imports_products_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_imports_products_timeseries;
IF OBJECT_ID('staging.vw_exports_services_quarterly', 'V') IS NOT NULL
    DROP VIEW staging.vw_exports_services_quarterly;
IF OBJECT_ID('staging.vw_imports_services_quarterly', 'V') IS NOT NULL
    DROP VIEW staging.vw_imports_services_quarterly;
IF OBJECT_ID('staging.vw_gdp_per_capita_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_gdp_per_capita_timeseries;
IF OBJECT_ID('staging.vw_urban_population_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_urban_population_timeseries;
IF OBJECT_ID('staging.vw_industry_construction_growth_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_industry_construction_growth_timeseries;
IF OBJECT_ID('staging.vw_world_exports_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_world_exports_timeseries;
IF OBJECT_ID('staging.vw_world_imports_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_world_imports_timeseries;
IF OBJECT_ID('staging.vw_calc_exp_pt_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_exp_pt_2024;
IF OBJECT_ID('staging.vw_calc_exp_world_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_exp_world_2024;
IF OBJECT_ID('staging.vw_calc_all_exp_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_all_exp_2024;
IF OBJECT_ID('staging.vw_calc_exp_prod_pt_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_exp_prod_pt_2024;
IF OBJECT_ID('staging.vw_calc_imp_pt_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_imp_pt_2024;
IF OBJECT_ID('staging.vw_calc_imp_prod_pt_2024', 'V') IS NOT NULL
    DROP VIEW staging.vw_calc_imp_prod_pt_2024;
IF OBJECT_ID('staging.vw_imports_country_segment_timeseries', 'V') IS NOT NULL
    DROP VIEW staging.vw_imports_country_segment_timeseries;
GO

IF OBJECT_ID('staging.ref_country_lookup', 'U') IS NOT NULL
    DROP TABLE staging.ref_country_lookup;
IF OBJECT_ID('staging.ref_hs_product', 'U') IS NOT NULL
    DROP TABLE staging.ref_hs_product;
GO

/* ---------------------------------------------------------------------------
   Reference tables (to be slowly enriched by data stewards)
--------------------------------------------------------------------------- */
CREATE TABLE staging.ref_country_lookup (
    CountryLabel   VARCHAR(150) NOT NULL PRIMARY KEY,
    ISO3           CHAR(3)      NULL,
    StandardName   VARCHAR(150) NULL,
    Continent      VARCHAR(50)  NULL,
    Region         VARCHAR(100) NULL
);
GO

INSERT INTO staging.ref_country_lookup (CountryLabel, ISO3, StandardName, Continent, Region)
SELECT v.CountryLabel, v.ISO3, v.StandardName, v.Continent, v.Region
FROM (VALUES
    ('World', 'WLD', 'World', 'Global', 'Global'),
    ('Portugal', 'PRT', 'Portugal', 'Europe', 'Southern Europe'),
    ('France', 'FRA', 'France', 'Europe', 'Western Europe'),
    ('Spain', 'ESP', 'Spain', 'Europe', 'Southern Europe'),
    ('United States of America', 'USA', 'United States', 'North America', 'North America'),
    ('China', 'CHN', 'China', 'Asia', 'East Asia'),
    ('Italy', 'ITA', 'Italy', 'Europe', 'Southern Europe'),
    ('Germany', 'DEU', 'Germany', 'Europe', 'Western Europe'),
    ('United Kingdom', 'GBR', 'United Kingdom', 'Europe', 'Northern Europe'),
    ('Japan', 'JPN', 'Japan', 'Asia', 'East Asia'),
    ('Russia', 'RUS', 'Russian Federation', 'Europe', 'Eastern Europe')
) AS v(CountryLabel, ISO3, StandardName, Continent, Region)
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.ref_country_lookup AS c
    WHERE c.CountryLabel = v.CountryLabel
);

INSERT INTO staging.ref_country_lookup (CountryLabel, ISO3, StandardName, Continent, Region)
SELECT DISTINCT
    up.[Country Name]          AS CountryLabel,
    up.[Country Code]          AS ISO3,
    up.[Country Name]          AS StandardName,
    'Unknown'                  AS Continent,
    'Unknown'                  AS Region
FROM dbo.urban_population AS up
WHERE up.[Country Code] IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM staging.ref_country_lookup AS c
        WHERE c.ISO3 = up.[Country Code]
    );
GO

CREATE TABLE staging.ref_hs_product (
    HSCode        VARCHAR(10)  NOT NULL PRIMARY KEY,
    ProductLabel  VARCHAR(255) NOT NULL,
    ProductGroup  VARCHAR(100) NULL
);
GO

INSERT INTO staging.ref_hs_product (HSCode, ProductLabel, ProductGroup)
SELECT v.HSCode, v.ProductLabel, v.ProductGroup
FROM (VALUES
    ('6907', 'Ceramic flags and paving, hearth or wall tiles; ceramic mosaic cubes', 'Ceramics'),
    ('6908', 'Glazed ceramic flags and tiles', 'Ceramics'),
    ('6910', 'Ceramic sinks, washbasins, baths and similar sanitary fixtures', 'Sanitaryware'),
    ('6912', 'Ceramic tableware, kitchenware, other household and toilet articles', 'Household'),
    ('6913', 'Statuettes and ornamental ceramics', 'Decor')
) AS v(HSCode, ProductLabel, ProductGroup)
WHERE NOT EXISTS (
    SELECT 1
    FROM staging.ref_hs_product AS p
    WHERE p.HSCode = v.HSCode
);
GO

/* ---------------------------------------------------------------------------
   Helper expression for repeated country clean-up logic
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_country_name_cleanup AS
SELECT
    CountryLabel,
    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(LTRIM(RTRIM(CountryLabel)), ' ', '_'),
            '-', '_'),
        '&', 'and')
    ) AS CountrySlug
FROM staging.ref_country_lookup;
GO

/* ---------------------------------------------------------------------------
   Country-level exports (Portugal -> partner countries, annual)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_exports_country_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Importers)) AS RawCountry,
        [Exported value in 2005],
        [Exported value in 2006],
        [Exported value in 2007],
        [Exported value in 2008],
        [Exported value in 2009],
        [Exported value in 2010],
        [Exported value in 2011],
        [Exported value in 2012],
        [Exported value in 2013],
        [Exported value in 2014],
        [Exported value in 2015],
        [Exported value in 2016],
        [Exported value in 2017],
        [Exported value in 2018],
        [Exported value in 2019],
        [Exported value in 2020],
        [Exported value in 2021],
        [Exported value in 2022],
        [Exported value in 2023],
        [Exported value in 2024]
    FROM dbo.exports_country_csv_trade_map_list_of_importing_markets_for_a_product_exported_by_portugal_xls
)
SELECT
    base.RawCountry                                              AS RawCountryLabel,
    COALESCE(ref.StandardName, base.RawCountry)                  AS CountryName,
    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(base.RawCountry, ' ', '_'),
            '-', '_'),
        '&', 'and')
    )                                                            AS CountrySlug,
    ref.ISO3,
    ref.Continent,
    ref.Region,
    TRY_CONVERT(INT, year_data.YearLabel)                        AS Ano,
    year_data.Amount                                             AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2005])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2006])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2007])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2008])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2009])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2010])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2011])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2012])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2013])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2014])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2015])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2016])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2017])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2018])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2019])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2020])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2021])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2022])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2023])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2024]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = base.RawCountry
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Country-level imports (world -> ceramic HS codes, annual)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_imports_country_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Importers)) AS RawCountry,
        [Imported value in 2005],
        [Imported value in 2006],
        [Imported value in 2007],
        [Imported value in 2008],
        [Imported value in 2009],
        [Imported value in 2010],
        [Imported value in 2011],
        [Imported value in 2012],
        [Imported value in 2013],
        [Imported value in 2014],
        [Imported value in 2015],
        [Imported value in 2016],
        [Imported value in 2017],
        [Imported value in 2018],
        [Imported value in 2019],
        [Imported value in 2020],
        [Imported value in 2021],
        [Imported value in 2022],
        [Imported value in 2023],
        [Imported value in 2024]
    FROM dbo.imports_country_csv_trade_map_list_of_importers_for_the_selected_product_ceramic_products_xls
)
SELECT
    base.RawCountry                                              AS RawCountryLabel,
    COALESCE(ref.StandardName, base.RawCountry)                  AS CountryName,
    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(base.RawCountry, ' ', '_'),
            '-', '_'),
        '&', 'and')
    )                                                            AS CountrySlug,
    ref.ISO3,
    ref.Continent,
    ref.Region,
    TRY_CONVERT(INT, year_data.YearLabel)                        AS Ano,
    year_data.Amount                                             AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2005])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2006])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2007])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2008])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2009])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2010])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2011])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2012])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2013])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2014])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2015])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2016])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2017])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2018])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2024]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = base.RawCountry
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   World exports by exporter (annual)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_world_exports_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Exporters)) AS RawCountry,
        [Exported value in 2005],
        [Exported value in 2006],
        [Exported value in 2007],
        [Exported value in 2008],
        [Exported value in 2009],
        [Exported value in 2010],
        [Exported value in 2011],
        [Exported value in 2012],
        [Exported value in 2013],
        [Exported value in 2014],
        [Exported value in 2015],
        [Exported value in 2016],
        [Exported value in 2017],
        [Exported value in 2018],
        [Exported value in 2019],
        [Exported value in 2020],
        [Exported value in 2021],
        [Exported value in 2022],
        [Exported value in 2023],
        [Exported value in 2024]
    FROM dbo.exports_csv_trade_map_list_of_exporters_for_the_selected_product_ceramic_products_xls
)
SELECT
    base.RawCountry                                            AS RawCountryLabel,
    COALESCE(ref.StandardName, base.RawCountry)                AS CountryName,
    ref.ISO3,
    TRY_CONVERT(INT, year_data.YearLabel)                      AS Ano,
    year_data.Amount                                           AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2005])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2006])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2007])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2008])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2009])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2010])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2011])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2012])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2013])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2014])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2015])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2016])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2017])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2018])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2019])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2020])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2021])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2022])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2023])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2024]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = base.RawCountry
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   World imports by importer (annual)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_world_imports_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Importers)) AS RawCountry,
        [Imported value in 2005],
        [Imported value in 2006],
        [Imported value in 2007],
        [Imported value in 2008],
        [Imported value in 2009],
        [Imported value in 2010],
        [Imported value in 2011],
        [Imported value in 2012],
        [Imported value in 2013],
        [Imported value in 2014],
        [Imported value in 2015],
        [Imported value in 2016],
        [Imported value in 2017],
        [Imported value in 2018],
        [Imported value in 2019],
        [Imported value in 2020],
        [Imported value in 2021],
        [Imported value in 2022],
        [Imported value in 2023],
        [Imported value in 2024]
    FROM dbo.imports_country_csv_trade_map_list_of_importers_for_the_selected_product_ceramic_products_xls
)
SELECT
    base.RawCountry                                            AS RawCountryLabel,
    COALESCE(ref.StandardName, base.RawCountry)                AS CountryName,
    ref.ISO3,
    TRY_CONVERT(INT, year_data.YearLabel)                      AS Ano,
    year_data.Amount                                           AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2005])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2006])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2007])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2008])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2009])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2010])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2011])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2012])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2013])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2014])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2015])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2016])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2017])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2018])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2024]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = base.RawCountry
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Product-level exports (Portugal -> world, annual totals per HS code)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_exports_products_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(REPLACE(Code, '''', ''))) AS HSCode,
        LTRIM(RTRIM([Product label]))         AS ProductLabel,
        [Exported value in 2005],
        [Exported value in 2006],
        [Exported value in 2007],
        [Exported value in 2008],
        [Exported value in 2009],
        [Exported value in 2010],
        [Exported value in 2011],
        [Exported value in 2012],
        [Exported value in 2013],
        [Exported value in 2014],
        [Exported value in 2015],
        [Exported value in 2016],
        [Exported value in 2017],
        [Exported value in 2018],
        [Exported value in 2019],
        [Exported value in 2020],
        [Exported value in 2021],
        [Exported value in 2022],
        [Exported value in 2023],
        [Exported value in 2024]
    FROM dbo.exports_products_csv_trade_map_list_of_products_exported_by_portugal_xls
)
SELECT
    base.HSCode,
    COALESCE(ref.ProductLabel, base.ProductLabel)                AS ProductLabel,
    ref.ProductGroup,
    TRY_CONVERT(INT, year_data.YearLabel)                        AS Ano,
    year_data.Amount                                             AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2005])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2006])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2007])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2008])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2009])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2010])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2011])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2012])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2013])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2014])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2015])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2016])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2017])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2018])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2019])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2020])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2021])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2022])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2023])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [Exported value in 2024]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_hs_product AS ref
    ON ref.HSCode = base.HSCode
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Product-level imports (world demand per HS code, annual)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_imports_products_timeseries AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(REPLACE([Product code], '''', ''))) AS HSCode,
        LTRIM(RTRIM([Product label]))                   AS ProductLabel,
        [imported value in 2005, US Dollar thousand],
        [imported value in 2006, US Dollar thousand],
        [imported value in 2007, US Dollar thousand],
        [imported value in 2008, US Dollar thousand],
        [imported value in 2009, US Dollar thousand],
        [imported value in 2010, US Dollar thousand],
        [imported value in 2011, US Dollar thousand],
        [imported value in 2012, US Dollar thousand],
        [imported value in 2013, US Dollar thousand],
        [imported value in 2014, US Dollar thousand],
        [imported value in 2015, US Dollar thousand],
        [imported value in 2016, US Dollar thousand],
        [imported value in 2017, US Dollar thousand],
        [imported value in 2018, US Dollar thousand],
        [imported value in 2019, US Dollar thousand],
        [imported value in 2020, US Dollar thousand],
        [imported value in 2021, US Dollar thousand],
        [imported value in 2022, US Dollar thousand],
        [imported value in 2023, US Dollar thousand],
        [imported value in 2024, US Dollar thousand]
    FROM dbo.imports_products_csv_trade_map_list_of_imported_products_for_the_selected_product_ceramic_products_xls
)
SELECT
    base.HSCode,
    COALESCE(ref.ProductLabel, base.ProductLabel)                AS ProductLabel,
    ref.ProductGroup,
    TRY_CONVERT(INT, year_data.YearLabel)                        AS Ano,
    year_data.Amount                                             AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2005', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2005, US Dollar thousand])),
    ('2006', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2006, US Dollar thousand])),
    ('2007', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2007, US Dollar thousand])),
    ('2008', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2008, US Dollar thousand])),
    ('2009', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2009, US Dollar thousand])),
    ('2010', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2010, US Dollar thousand])),
    ('2011', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2011, US Dollar thousand])),
    ('2012', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2012, US Dollar thousand])),
    ('2013', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2013, US Dollar thousand])),
    ('2014', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2014, US Dollar thousand])),
    ('2015', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2015, US Dollar thousand])),
    ('2016', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2016, US Dollar thousand])),
    ('2017', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2017, US Dollar thousand])),
    ('2018', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2018, US Dollar thousand])),
    ('2019', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2019, US Dollar thousand])),
    ('2020', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2020, US Dollar thousand])),
    ('2021', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2021, US Dollar thousand])),
    ('2022', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2022, US Dollar thousand])),
    ('2023', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2023, US Dollar thousand])),
    ('2024', TRY_CONVERT(DECIMAL(18, 2), [imported value in 2024, US Dollar thousand]))
) AS year_data(YearLabel, Amount)
LEFT JOIN staging.ref_hs_product AS ref
        ON ref.HSCode = base.HSCode
WHERE year_data.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Country-level imports for selected HS codes (tiles, glazed tiles, sanitaryware)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_imports_country_segment_timeseries AS
WITH segment_data AS (
    SELECT
        '6907' AS HSCode,
        LTRIM(RTRIM(Importers)) AS RawCountry,
        year_data.YearLabel,
        year_data.Amount
    FROM dbo.trade_map_list_of_importers_for_the_selected_product_ceramic_flags_and_paving_hearth_xls AS base
    CROSS APPLY (VALUES
        ('2005', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2005])),
        ('2006', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2006])),
        ('2007', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2007])),
        ('2008', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2008])),
        ('2009', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2009])),
        ('2010', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2010])),
        ('2011', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2011])),
        ('2012', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2012])),
        ('2013', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2013])),
        ('2014', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2014])),
        ('2015', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2015])),
        ('2016', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2016])),
        ('2017', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2017])),
        ('2018', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2018])),
        ('2019', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019])),
        ('2020', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020])),
        ('2021', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021])),
        ('2022', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022])),
        ('2023', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023])),
        ('2024', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2024]))
    ) AS year_data(YearLabel, Amount)
    WHERE year_data.Amount IS NOT NULL

    UNION ALL

    SELECT
        '6908' AS HSCode,
        LTRIM(RTRIM(Importers)) AS RawCountry,
        year_data.YearLabel,
        year_data.Amount
    FROM dbo.trade_map_list_of_importers_for_the_selected_product_glazed_ceramic_flags_and_paving_hearth_xls AS base
    CROSS APPLY (VALUES
        ('2005', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2005])),
        ('2006', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2006])),
        ('2007', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2007])),
        ('2008', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2008])),
        ('2009', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2009])),
        ('2010', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2010])),
        ('2011', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2011])),
        ('2012', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2012])),
        ('2013', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2013])),
        ('2014', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2014])),
        ('2015', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2015])),
        ('2016', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2016])),
        ('2017', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2017])),
        ('2018', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2018])),
        ('2019', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019])),
        ('2020', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020])),
        ('2021', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021])),
        ('2022', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022])),
        ('2023', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023])),
        ('2024', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2024]))
    ) AS year_data(YearLabel, Amount)
    WHERE year_data.Amount IS NOT NULL

    UNION ALL

    SELECT
        '6910' AS HSCode,
        LTRIM(RTRIM(Importers)) AS RawCountry,
        year_data.YearLabel,
        year_data.Amount
    FROM dbo.trade_map_list_of_importers_for_the_selected_product_ceramic_sinks_washbasins_xls AS base
    CROSS APPLY (VALUES
        ('2005', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2005])),
        ('2006', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2006])),
        ('2007', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2007])),
        ('2008', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2008])),
        ('2009', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2009])),
        ('2010', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2010])),
        ('2011', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2011])),
        ('2012', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2012])),
        ('2013', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2013])),
        ('2014', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2014])),
        ('2015', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2015])),
        ('2016', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2016])),
        ('2017', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2017])),
        ('2018', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2018])),
        ('2019', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019])),
        ('2020', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020])),
        ('2021', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021])),
        ('2022', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022])),
        ('2023', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023])),
        ('2024', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2024]))
    ) AS year_data(YearLabel, Amount)
    WHERE year_data.Amount IS NOT NULL
)
SELECT
    segment_data.HSCode,
    COALESCE(prod.ProductLabel, segment_data.HSCode) AS ProductLabel,
    segment_data.RawCountry                              AS RawCountryLabel,
    COALESCE(ref.StandardName, segment_data.RawCountry)  AS CountryName,
    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(segment_data.RawCountry, ' ', '_'),
            '-', '_'),
        '&', 'and')
    )                                                   AS CountrySlug,
    ref.ISO3,
    ref.Continent,
    ref.Region,
    TRY_CONVERT(INT, segment_data.YearLabel)            AS Ano,
    segment_data.Amount                                 AS Valor_USD
FROM segment_data
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = segment_data.RawCountry
LEFT JOIN staging.ref_hs_product AS prod
    ON prod.HSCode = segment_data.HSCode;
GO

/* ---------------------------------------------------------------------------
   Construction services exported by Portugal (quarterly)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_exports_services_quarterly AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Code))           AS ServiceCode,
        LTRIM(RTRIM([Service label])) AS ServiceLabel,
        [Exported Value in 2019-Q1],
        [Exported Value in 2019-Q2],
        [Exported Value in 2019-Q3],
        [Exported Value in 2019-Q4],
        [Exported Value in 2020-Q1],
        [Exported Value in 2020-Q2],
        [Exported Value in 2020-Q3],
        [Exported Value in 2020-Q4],
        [Exported Value in 2021-Q1],
        [Exported Value in 2021-Q2],
        [Exported Value in 2021-Q3],
        [Exported Value in 2021-Q4],
        [Exported Value in 2022-Q1],
        [Exported Value in 2022-Q2],
        [Exported Value in 2022-Q3],
        [Exported Value in 2022-Q4],
        [Exported Value in 2023-Q1],
        [Exported Value in 2023-Q2],
        [Exported Value in 2023-Q3],
        [Exported Value in 2023-Q4]
    FROM dbo.exports_services_csv_trade_map_list_of_services_exported_by_portugal_construction_1_xls
)
SELECT
    ServiceCode,
    ServiceLabel,
    TRY_CONVERT(INT, LEFT(period.PeriodLabel, 4))                AS Ano,
    RIGHT(period.PeriodLabel, 2)                                 AS Trimestre,
    period.Amount                                                AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2019-Q1', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2019-Q1])),
    ('2019-Q2', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2019-Q2])),
    ('2019-Q3', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2019-Q3])),
    ('2019-Q4', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2019-Q4])),
    ('2020-Q1', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2020-Q1])),
    ('2020-Q2', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2020-Q2])),
    ('2020-Q3', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2020-Q3])),
    ('2020-Q4', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2020-Q4])),
    ('2021-Q1', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2021-Q1])),
    ('2021-Q2', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2021-Q2])),
    ('2021-Q3', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2021-Q3])),
    ('2021-Q4', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2021-Q4])),
    ('2022-Q1', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2022-Q1])),
    ('2022-Q2', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2022-Q2])),
    ('2022-Q3', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2022-Q3])),
    ('2022-Q4', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2022-Q4])),
    ('2023-Q1', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2023-Q1])),
    ('2023-Q2', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2023-Q2])),
    ('2023-Q3', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2023-Q3])),
    ('2023-Q4', TRY_CONVERT(DECIMAL(18, 2), [Exported Value in 2023-Q4]))
) AS period(PeriodLabel, Amount)
WHERE period.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Construction services imports (world demand, quarterly)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_imports_services_quarterly AS
WITH base AS (
    SELECT
        LTRIM(RTRIM(Importers)) AS RawCountry,
        [Imported value in 2019-Q1],
        [Imported value in 2019-Q2],
        [Imported value in 2019-Q3],
        [Imported value in 2019-Q4],
        [Imported value in 2020-Q1],
        [Imported value in 2020-Q2],
        [Imported value in 2020-Q3],
        [Imported value in 2020-Q4],
        [Imported value in 2021-Q1],
        [Imported value in 2021-Q2],
        [Imported value in 2021-Q3],
        [Imported value in 2021-Q4],
        [Imported value in 2022-Q1],
        [Imported value in 2022-Q2],
        [Imported value in 2022-Q3],
        [Imported value in 2022-Q4],
        [Imported value in 2023-Q1],
        [Imported value in 2023-Q2],
        [Imported value in 2023-Q3],
        [Imported value in 2023-Q4]
    FROM dbo.imports_services_csv_trade_map_list_of_importers_for_the_selected_service_construction_xls
)
SELECT
    base.RawCountry                                              AS RawCountryLabel,
    COALESCE(ref.StandardName, base.RawCountry)                  AS CountryName,
    LOWER(
        REPLACE(
            REPLACE(
                REPLACE(base.RawCountry, ' ', '_'),
            '-', '_'),
        '&', 'and')
    )                                                            AS CountrySlug,
    ref.ISO3,
    TRY_CONVERT(INT, LEFT(period.PeriodLabel, 4))                AS Ano,
    RIGHT(period.PeriodLabel, 2)                                 AS Trimestre,
    period.Amount                                                AS Valor_USD
FROM base
CROSS APPLY (VALUES
    ('2019-Q1', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019-Q1])),
    ('2019-Q2', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019-Q2])),
    ('2019-Q3', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019-Q3])),
    ('2019-Q4', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2019-Q4])),
    ('2020-Q1', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020-Q1])),
    ('2020-Q2', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020-Q2])),
    ('2020-Q3', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020-Q3])),
    ('2020-Q4', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2020-Q4])),
    ('2021-Q1', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021-Q1])),
    ('2021-Q2', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021-Q2])),
    ('2021-Q3', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021-Q3])),
    ('2021-Q4', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2021-Q4])),
    ('2022-Q1', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022-Q1])),
    ('2022-Q2', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022-Q2])),
    ('2022-Q3', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022-Q3])),
    ('2022-Q4', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2022-Q4])),
    ('2023-Q1', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023-Q1])),
    ('2023-Q2', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023-Q2])),
    ('2023-Q3', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023-Q3])),
    ('2023-Q4', TRY_CONVERT(DECIMAL(18, 2), [Imported value in 2023-Q4]))
) AS period(PeriodLabel, Amount)
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = base.RawCountry
WHERE period.Amount IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   GDP per capita timeseries (World Bank)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_gdp_per_capita_timeseries AS
WITH unpivoted AS (
    SELECT
        LTRIM(RTRIM([Country Name])) AS CountryName,
        [Country Code]               AS CountryCode,
        YearLabel,
        TRY_CONVERT(DECIMAL(18, 2), Value) AS GDP_PerCapita_USD
    FROM dbo.gdp_per_capita
    UNPIVOT (
        Value FOR YearLabel IN (
            [1960],[1961],[1962],[1963],[1964],[1965],[1966],[1967],[1968],[1969],
            [1970],[1971],[1972],[1973],[1974],[1975],[1976],[1977],[1978],[1979],
            [1980],[1981],[1982],[1983],[1984],[1985],[1986],[1987],[1988],[1989],
            [1990],[1991],[1992],[1993],[1994],[1995],[1996],[1997],[1998],[1999],
            [2000],[2001],[2002],[2003],[2004],[2005],[2006],[2007],[2008],[2009],
            [2010],[2011],[2012],[2013],[2014],[2015],[2016],[2017],[2018],[2019],
            [2020],[2021],[2022],[2023],[2024]
        )
    ) AS up
)
SELECT
    CountryName,
    CountryCode,
    TRY_CONVERT(INT, YearLabel) AS Ano,
    GDP_PerCapita_USD          AS Valor_USD
FROM unpivoted
WHERE GDP_PerCapita_USD IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Urban population timeseries (World Bank)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_urban_population_timeseries AS
WITH unpivoted AS (
    SELECT
        LTRIM(RTRIM([Country Name])) AS CountryName,
        [Country Code]               AS CountryCode,
        YearLabel,
        TRY_CONVERT(DECIMAL(18, 2), Value) AS UrbanPopulation
    FROM dbo.urban_population
    UNPIVOT (
        Value FOR YearLabel IN (
            [1960],[1961],[1962],[1963],[1964],[1965],[1966],[1967],[1968],[1969],
            [1970],[1971],[1972],[1973],[1974],[1975],[1976],[1977],[1978],[1979],
            [1980],[1981],[1982],[1983],[1984],[1985],[1986],[1987],[1988],[1989],
            [1990],[1991],[1992],[1993],[1994],[1995],[1996],[1997],[1998],[1999],
            [2000],[2001],[2002],[2003],[2004],[2005],[2006],[2007],[2008],[2009],
            [2010],[2011],[2012],[2013],[2014],[2015],[2016],[2017],[2018],[2019],
            [2020],[2021],[2022],[2023],[2024]
        )
    ) AS up
)
SELECT
    CountryName,
    CountryCode,
    TRY_CONVERT(INT, YearLabel) AS Ano,
    UrbanPopulation             AS Total_Populacao
FROM unpivoted
WHERE UrbanPopulation IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   Industry (including construction) value added growth (World Bank)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_industry_construction_growth_timeseries AS
WITH unpivoted AS (
    SELECT
        LTRIM(RTRIM([Country Name])) AS CountryName,
        [Country Code]               AS CountryCode,
        [Indicator Code]             AS IndicatorCode,
        YearLabel,
        TRY_CONVERT(DECIMAL(18, 4), Value) AS GrowthPct
    FROM dbo.api_nv_ind_totl_kd_zg_ds2_en_csv_v2_6502
    UNPIVOT (
        Value FOR YearLabel IN (
            [1960],[1961],[1962],[1963],[1964],[1965],[1966],[1967],[1968],[1969],
            [1970],[1971],[1972],[1973],[1974],[1975],[1976],[1977],[1978],[1979],
            [1980],[1981],[1982],[1983],[1984],[1985],[1986],[1987],[1988],[1989],
            [1990],[1991],[1992],[1993],[1994],[1995],[1996],[1997],[1998],[1999],
            [2000],[2001],[2002],[2003],[2004],[2005],[2006],[2007],[2008],[2009],
            [2010],[2011],[2012],[2013],[2014],[2015],[2016],[2017],[2018],[2019],
            [2020],[2021],[2022],[2023],[2024]
        )
    ) AS up
)
SELECT
    CountryName,
    CountryCode,
    TRY_CONVERT(INT, YearLabel) AS Ano,
    GrowthPct
FROM unpivoted
WHERE GrowthPct IS NOT NULL
  AND CountryCode IS NOT NULL
  AND IndicatorCode = 'NV.IND.TOTL.KD.ZG';
GO

/* ---------------------------------------------------------------------------
   2024 snapshot metrics (calc tables)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_calc_exp_pt_2024 AS
SELECT
    LTRIM(RTRIM(src.Importers))                                AS CountryName,
    ref.ISO3,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)       AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)    AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.SharePortugalTxt)   AS SharePortugalExportsPct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2020Txt)      AS Growth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2023Txt)      AS Growth2023_2024_Pct,
    TRY_CONVERT(INT, fmt.RankingTxt)                    AS RankingWorldImports,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ShareWorldTxt)      AS ShareWorldImportsPct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.PartnerGrowthTxt)   AS PartnerGrowth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)     AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)   AS ConcentrationIndex,
    TRY_CONVERT(DECIMAL(18, 4), fmt.AvgTariffTxt)       AS AvgTariffPct
FROM dbo.exports_country_csv_trade_map_list_of_importing_markets_for_the_product_exported_by_portugal_in_2024_xls AS src
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE(src.[Value exported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE(src.[Trade balance 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Share in Portugal's exports (%)], ',', ''), '(', '-'), ')', '') AS SharePortugalTxt,
        REPLACE(REPLACE(REPLACE(src.[Growth in exported value between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS Growth2020Txt,
        REPLACE(REPLACE(REPLACE(src.[Growth in exported value between 2023-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS Growth2023Txt,
        REPLACE(REPLACE(REPLACE(src.[Ranking of partner countries in world imports], ',', ''), '(', '-'), ')', '') AS RankingTxt,
        REPLACE(REPLACE(REPLACE(src.[Share of partner countries in world imports (%)], ',', ''), '(', '-'), ')', '') AS ShareWorldTxt,
        REPLACE(REPLACE(REPLACE(src.[Total imports growth in value of partner countries between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS PartnerGrowthTxt,
        REPLACE(REPLACE(REPLACE(src.[Average distance between partner countries and all their supplying markets (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Concentration of all supplying countries of partner countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt,
        REPLACE(REPLACE(REPLACE(src.[Average tariff (estimated) faced by Portugal (%)], ',', ''), '(', '-'), ')', '') AS AvgTariffTxt
) AS fmt
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = LTRIM(RTRIM(src.Importers))
WHERE ref.ISO3 IS NOT NULL;
GO

CREATE OR ALTER VIEW staging.vw_calc_exp_world_2024 AS
SELECT
    LTRIM(RTRIM(src.Exporters))                                AS CountryName,
    ref.ISO3,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)            AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)         AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2020Txt)           AS Growth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2023Txt)           AS Growth2023_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ShareWorldTxt)           AS ShareWorldExportsPct,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)          AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)        AS ConcentrationIndex
FROM dbo.exports_csv_trade_map_list_of_exporters_for_the_selected_product_in_2024_ceramic_products_xls AS src
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE(src.[Value exported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE(src.[Trade balance in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2020-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2020Txt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2023-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2023Txt,
        REPLACE(REPLACE(REPLACE(src.[Share in world exports (%)], ',', ''), '(', '-'), ')', '') AS ShareWorldTxt,
        REPLACE(REPLACE(REPLACE(src.[Average distance of importing countries (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Concentration of importing countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt
) AS fmt
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = LTRIM(RTRIM(src.Exporters))
WHERE ref.ISO3 IS NOT NULL;
GO

/* ---------------------------------------------------------------------------
   2024 snapshot – ALL products (exportadores mundiais)
--------------------------------------------------------------------------- */
CREATE OR ALTER VIEW staging.vw_calc_all_exp_2024 AS
SELECT
    LTRIM(RTRIM(src.[Exporters]))                              AS CountryName,
    ref.ISO3,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)            AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)         AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2020Txt)           AS Growth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2023Txt)           AS Growth2023_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ShareWorldTxt)           AS ShareWorldExportsPct,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)          AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)        AS ConcentrationIndex
FROM dbo.trade_map_list_of_exporters_for_the_selected_product_in_2024_all_products_xls AS src
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE(src.[Value exported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE(src.[Trade balance in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2020-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2020Txt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2023-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2023Txt,
        REPLACE(REPLACE(REPLACE(src.[Share in world exports (%)], ',', ''), '(', '-'), ')', '') AS ShareWorldTxt,
        REPLACE(REPLACE(REPLACE(src.[Average distance of importing countries (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Concentration of importing countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt
) AS fmt
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = LTRIM(RTRIM(src.[Exporters]))
WHERE ref.ISO3 IS NOT NULL;
GO

CREATE OR ALTER VIEW staging.vw_calc_exp_prod_pt_2024 AS
SELECT
    LTRIM(RTRIM(REPLACE([Code], '''', '')))                   AS HSCode,
    LTRIM(RTRIM([Product label]))                             AS ProductLabel,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)           AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)        AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthValue2020Txt)     AS GrowthValue2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthQty2020Txt)       AS GrowthQty2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthValue2023Txt)     AS GrowthValue2023_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.WorldImportGrowthTxt)   AS WorldImportGrowth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ShareWorldTxt)          AS ShareWorldExportsPct,
    TRY_CONVERT(INT, fmt.RankingTxt)                        AS RankingWorldExports,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)         AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)       AS ConcentrationIndex
FROM dbo.exports_products_csv_trade_map_list_of_products_at_4_digits_level_exported_by_portugal_in_2024_xls
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE([Value exported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE([Trade balance 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE([Annual growth in value between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthValue2020Txt,
        REPLACE(REPLACE(REPLACE([Annual growth in quantity between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthQty2020Txt,
        REPLACE(REPLACE(REPLACE([Annual growth in value between 2023-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthValue2023Txt,
        REPLACE(REPLACE(REPLACE([Annual growth of world imports between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS WorldImportGrowthTxt,
        REPLACE(REPLACE(REPLACE([Share in world exports (%)], ',', ''), '(', '-'), ')', '') AS ShareWorldTxt,
        REPLACE(REPLACE(REPLACE([Ranking in world exports], ',', ''), '(', '-'), ')', '') AS RankingTxt,
        REPLACE(REPLACE(REPLACE([Average distance of importing countries (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE([Concentration of importing countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt
) AS fmt;
GO

CREATE OR ALTER VIEW staging.vw_calc_imp_pt_2024 AS
SELECT
    LTRIM(RTRIM(src.Importers))                                AS CountryName,
    ref.ISO3,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)            AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)         AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2020Txt)           AS Growth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.Growth2023Txt)           AS Growth2023_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ShareWorldTxt)           AS ShareWorldImportsPct,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)          AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)        AS ConcentrationIndex,
    TRY_CONVERT(DECIMAL(18, 4), fmt.AvgTariffTxt)            AS AvgTariffPct
FROM dbo.imports_country_csv_trade_map_list_of_importers_for_the_selected_product_in_2024_ceramic_products_xls AS src
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE(src.[Value imported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE(src.[Trade balance in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2020-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2020Txt,
        REPLACE(REPLACE(REPLACE(src.[Annual growth in value between 2023-2024 (%)], ',', ''), '(', '-'), ')', '') AS Growth2023Txt,
        REPLACE(REPLACE(REPLACE(src.[Share in world imports (%)], ',', ''), '(', '-'), ')', '') AS ShareWorldTxt,
        REPLACE(REPLACE(REPLACE(src.[Average distance of supplying countries (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE(src.[Concentration of supplying countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt,
        REPLACE(REPLACE(REPLACE(src.[Average tariff (estimated) applied by the country (%)], ',', ''), '(', '-'), ')', '') AS AvgTariffTxt
) AS fmt
LEFT JOIN staging.ref_country_lookup AS ref
    ON ref.CountryLabel = LTRIM(RTRIM(src.Importers))
WHERE ref.ISO3 IS NOT NULL;
GO

CREATE OR ALTER VIEW staging.vw_calc_imp_prod_pt_2024 AS
SELECT
    LTRIM(RTRIM(REPLACE([Code], '''', '')))                   AS HSCode,
    LTRIM(RTRIM([Product label]))                             AS ProductLabel,
    TRY_CONVERT(DECIMAL(18, 2), fmt.Value2024Txt)             AS Value2024_USD,
    TRY_CONVERT(DECIMAL(18, 2), fmt.TradeBalanceTxt)          AS TradeBalance2024_USD,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthValue2020Txt)       AS GrowthValue2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthQty2020Txt)         AS GrowthQty2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.GrowthValue2023Txt)       AS GrowthValue2023_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 4), fmt.WorldExportGrowthTxt)     AS WorldExportGrowth2020_2024_Pct,
    TRY_CONVERT(DECIMAL(18, 2), fmt.AvgDistanceTxt)           AS AvgDistanceKm,
    TRY_CONVERT(DECIMAL(18, 4), fmt.ConcentrationTxt)         AS ConcentrationIndex
FROM dbo.imports_products_csv_trade_map_list_of_products_at_4_digits_level_imported_in_2024_xls
CROSS APPLY (
    SELECT
        REPLACE(REPLACE(REPLACE([Value imported in 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS Value2024Txt,
        REPLACE(REPLACE(REPLACE([Trade balance 2024 (USD thousand)], ',', ''), '(', '-'), ')', '') AS TradeBalanceTxt,
        REPLACE(REPLACE(REPLACE([Annual growth in value between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthValue2020Txt,
        REPLACE(REPLACE(REPLACE([Annual growth in quantity between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthQty2020Txt,
        REPLACE(REPLACE(REPLACE([Annual growth in value between 2023-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS GrowthValue2023Txt,
        REPLACE(REPLACE(REPLACE([Annual growth of world exports between 2020-2024 (%, p.a.)], ',', ''), '(', '-'), ')', '') AS WorldExportGrowthTxt,
        REPLACE(REPLACE(REPLACE([Average distance of supplying countries (km)], ',', ''), '(', '-'), ')', '') AS AvgDistanceTxt,
        REPLACE(REPLACE(REPLACE([Concentration of supplying countries], ',', ''), '(', '-'), ')', '') AS ConcentrationTxt
) AS fmt;
GO
