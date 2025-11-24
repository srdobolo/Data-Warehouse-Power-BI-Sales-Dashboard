# Cross Selling

```dax
Purchased Both Products (Cell) = 
VAR ProdutoLinha  = SELECTEDVALUE('dw DIM_PRODUTO'[nome])
VAR ProdutoColuna = SELECTEDVALUE('Comparação Produtos'[nome])
VAR TransacoesLinha =
    CALCULATETABLE(
        VALUES('dw FACT_VENDAS'[transacao_id]),
        'dw FACT_VENDAS',
        'dw DIM_PRODUTO'[nome] = ProdutoLinha
    )
VAR TransacoesColuna =
    CALCULATETABLE(
        VALUES('dw FACT_VENDAS'[transacao_id]),
        TREATAS({ProdutoColuna}, 'dw DIM_PRODUTO'[nome])
    )
RETURN
IF(
    HASONEVALUE('dw DIM_PRODUTO'[nome]) &&
    HASONEVALUE('Comparação Produtos'[nome]) &&
    ProdutoLinha <> ProdutoColuna,
    COUNTROWS(INTERSECT(TransacoesLinha, TransacoesColuna))
)

Purchased Both Products = 
VAR Result =
    IF(
        ISINSCOPE('dw DIM_PRODUTO'[nome]) &&
        ISINSCOPE('Comparação Produtos'[nome]),
        [Purchased Both Products (Cell)],
        SUMX(
            SUMMARIZECOLUMNS(
                'dw DIM_PRODUTO'[nome],
                'Comparação Produtos'[nome]
            ),
            [Purchased Both Products (Cell)]
        )
    )
RETURN Result
```
