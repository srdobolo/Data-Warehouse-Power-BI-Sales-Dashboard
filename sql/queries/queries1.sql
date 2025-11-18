USE CeramicsWorldDB
GO

-- Exportações de ceramica por Portugal por Ano
SELECT TOP 15 * FROM dbo.exports_country_csv_trade_map_list_of_importing_markets_for_a_product_exported_by_portugal_xls;

-- Exportações de ceramica por Portugal (Factos 2024)
SELECT TOP 15 * FROM dbo.exports_country_csv_trade_map_list_of_importing_markets_for_the_product_exported_by_portugal_in_2024_xls;

-- Exportações Mundias de ceramica por ano
SELECT TOP 15 * FROM dbo.exports_csv_trade_map_list_of_exporters_for_the_selected_product_ceramic_products_xls;

-- Exportações Mundias de ceramica (Factos 2024)
SELECT TOP 15 * FROM dbo.exports_csv_trade_map_list_of_exporters_for_the_selected_product_in_2024_ceramic_products_xls;

-- Exportações Mundias de ceramica por Portugal por produto
SELECT TOP 15 * FROM dbo.exports_products_csv_trade_map_list_of_products_exported_by_portugal_xls;

-- Exportações Mundias de ceramica por Portugal por produto (Factos2024)
SELECT TOP 15 * FROM dbo.exports_products_csv_trade_map_list_of_products_at_4_digits_level_exported_by_portugal_in_2024_xls;

-- Exportações do sector construção por Portugal por Trimestre
SELECT * FROM dbo.exports_services_csv_trade_map_list_of_services_exported_by_portugal_construction_1_xls;

-- Importações de ceramica por país por ano
SELECT TOP 15 * FROM dbo.imports_country_csv_trade_map_list_of_importers_for_the_selected_product_ceramic_products_xls;

-- Importações de ceramica por país (factos 2024)
select top 15 * from dbo.imports_country_csv_trade_map_list_of_importers_for_the_selected_product_in_2024_ceramic_products_xls;

-- Importações mundiais de ceramica por produto por ano
select top 15 * from dbo.imports_products_csv_trade_map_list_of_imported_products_for_the_selected_product_ceramic_products_xls;

-- Importações mundas de ce ramica por produto (Factos)
select top 15 * from dbo.imports_products_csv_trade_map_list_of_products_at_4_digits_level_imported_in_2024_xls;

-- Importações mundias do sector de construção por trimestre
select top 15 * from dbo.imports_services_csv_trade_map_list_of_importers_for_the_selected_service_construction_xls;

-- GDP per capita por ano
SELECT TOP 15 * FROM dbo.gdp_per_capita;

-- População urbana por ano
select top 15 * from dbo.urban_population;