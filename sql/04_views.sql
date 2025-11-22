USE [SalesDW];
GO
SET LANGUAGE Portuguese;
SET NOCOUNT ON;
GO

CREATE OR ALTER VIEW dw.vw_cliente_loja AS
SELECT
    c.cliente_id,
    c.genero,
    c.loja_id,
    c.faixa_etaria,
    c.data_registo,
    l.nome   AS loja_nome,
    l.cidade,
    l.distrito,
    l.regiao,
    l.tipo
FROM dw.DIM_CLIENTE AS c
LEFT JOIN dw.DIM_LOJA AS l
    ON l.loja_id = c.loja_id;
GO

CREATE OR ALTER VIEW vw_Vendas_Agregadas AS
WITH OrdersPerClient AS (
    SELECT 
        cliente_id,
        COUNT(DISTINCT transacao_id) AS NoOfOrders
    FROM dw.FACT_VENDAS
    GROUP BY cliente_id
),
FirstLastOrder AS (
    SELECT
        f.cliente_id,
        MIN(d.data) AS FirstOrderDate,
        MAX(d.data) AS LastOrderDate
    FROM dw.FACT_VENDAS f
    LEFT JOIN dw.DIM_DATA d ON f.data_id = d.data_id
    GROUP BY f.cliente_id
)
SELECT 
    f.cliente_id,
    f.transacao_id,
    d.data AS DIM_DATA,
    l.nome AS DIM_LOJA,
    COUNT(*) AS NoOfItems,
    SUM(f.valor_total) AS Sales,
    flo.FirstOrderDate,
    flo.LastOrderDate,
    opc.NoOfOrders
FROM dw.FACT_VENDAS f
LEFT JOIN dw.DIM_DATA d 
    ON f.data_id = d.data_id
LEFT JOIN dw.DIM_LOJA l
    ON f.loja_id = l.loja_id
LEFT JOIN OrdersPerClient opc
    ON opc.cliente_id = f.cliente_id
LEFT JOIN FirstLastOrder flo
    ON flo.cliente_id = f.cliente_id
GROUP BY 
    f.cliente_id,
    f.transacao_id,
    d.data,
    l.nome,
    flo.FirstOrderDate,
    flo.LastOrderDate,
    opc.NoOfOrders;
