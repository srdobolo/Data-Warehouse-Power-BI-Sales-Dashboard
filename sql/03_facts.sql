USE [SalesDW];
GO
SET NOCOUNT ON; -- Evita mensagens desnecessárias de contagem de linhas afetadas

DROP TABLE IF EXISTS dw.FACT_VENDAS;
GO

CREATE TABLE dw.FACT_VENDAS (
    venda_id        BIGINT      PRIMARY KEY,
    data_id         INT         NOT NULL FOREIGN KEY REFERENCES dw.DIM_DATA(data_id),
    loja_id         INT         NOT NULL FOREIGN KEY REFERENCES dw.DIM_LOJA(loja_id),
    cliente_id      INT         NOT NULL FOREIGN KEY REFERENCES dw.DIM_CLIENTE(cliente_id),
    produto_id      INT         NOT NULL FOREIGN KEY REFERENCES dw.DIM_PRODUTO(produto_id),
    transacao_id    INT         NOT NULL,
    stock_inicial   INT         NULL,
    quantidade      INT         NOT NULL,
    preco_unitario  DECIMAL(18,2) NOT NULL,
    desconto_pct    DECIMAL(8,2)  NOT NULL,
    custo_unitario  DECIMAL(18,2) NOT NULL,
    valor_total     DECIMAL(18,2) NOT NULL
); 

INSERT INTO dw.FACT_VENDAS (
    venda_id, data_id, loja_id, cliente_id, produto_id, transacao_id, stock_inicial,
    quantidade, preco_unitario, desconto_pct, custo_unitario, valor_total
)
SELECT
    v.venda_id,
    d.data_id,
    v.loja_id,
    v.cliente_id,
    v.produto_id,
    DENSE_RANK() OVER (
        ORDER BY d.data_id, v.loja_id, v.cliente_id
    ) AS transacao_id,
    p.stock_inicial,
    v.quantidade,
    v.preco_unitario,
    v.desconto_percentual,
    v.custo_unitario,
    ISNULL(v.valor_total, v.quantidade * v.preco_unitario * (1 - v.desconto_percentual/100.0)) AS valor_total
FROM staging.vendas AS v
JOIN dw.DIM_DATA     AS d ON d.data = v.data_venda
LEFT JOIN staging.produtos AS p ON p.produto_id = v.produto_id;
GO
