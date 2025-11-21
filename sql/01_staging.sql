USE [SalesDW];
GO

DROP TABLE IF EXISTS staging.vendas;
CREATE TABLE staging.vendas (
    venda_id        BIGINT        NOT NULL,
    data_venda      DATE          NULL,
    loja_id         INT           NOT NULL,
    cliente_id      INT           NOT NULL,
    produto_id      INT           NOT NULL,
    quantidade      INT           NOT NULL,
    preco_unitario  DECIMAL(18,2) NOT NULL,
    desconto_percentual DECIMAL(8,2) NULL,
    custo_unitario  DECIMAL(18,2) NOT NULL,
    valor_total     DECIMAL(18,2) NULL
);

INSERT INTO staging.vendas
SELECT
    venda_id,
    TRY_CONVERT(DATE, data_venda) AS data_venda,
    loja_id,
    cliente_id,
    produto_id,
    quantidade,
    preco_unitario,
    desconto_percentual,
    custo_unitario,
    valor_total
FROM SalesDW.dbo.vendas;
GO

CREATE INDEX IX_staging_vendas_data     ON staging.vendas (data_venda);
CREATE INDEX IX_staging_vendas_loja     ON staging.vendas (loja_id);
CREATE INDEX IX_staging_vendas_cliente  ON staging.vendas (cliente_id);
CREATE INDEX IX_staging_vendas_produto  ON staging.vendas (produto_id);
GO
