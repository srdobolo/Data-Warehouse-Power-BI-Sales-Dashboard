# Visual Calculations

## Pareto

```dax
Percent of grand total = DIVIDE([Vendas Totais], COLLAPSEALL([Vendas Totais], ROWS))
```

```dax
Running sum = RUNNINGSUM([Percent of grand total],ORDERBY([Vendas Totais],DESC))
```

```dax
Greenline = IF([Pareto]<=.8,[Pareto],BLANK())
```

```dax
Redline = IF([Pareto]>.8,[Pareto],BLANK())
```

https://www.youtube.com/watch?v=xhc8WNoeyos

## Cross Selling Matrix

### Criar Tabela Comparação

```dax
Comparação Produtos = 
SUMMARIZE('dw DIM_PRODUTO','dw DIM_PRODUTO'[produto_id],'dw DIM_PRODUTO'[nome])
```

### Medida

```dax
Purchased Both Products (Cell) = 
VAR ProdutoLinha  = SELECTEDVALUE('dw DIM_PRODUTO'[produto_id])
VAR ProdutoColuna = SELECTEDVALUE('Comparação Produtos'[produto_id])
VAR TransacoesLinha =
    CALCULATETABLE(
        VALUES('dw FACT_VENDAS'[transacao_id]),
        'dw FACT_VENDAS',
        'dw DIM_PRODUTO'[produto_id] = ProdutoLinha
    )
VAR TransacoesColuna =
    CALCULATETABLE(
        VALUES('dw FACT_VENDAS'[transacao_id]),
        TREATAS({ProdutoColuna}, 'dw DIM_PRODUTO'[produto_id])
    )
RETURN
IF(
    HASONEVALUE('dw DIM_PRODUTO'[produto_id]) &&
    HASONEVALUE('Comparação Produtos'[produto_id]) &&
    ProdutoLinha <> ProdutoColuna,
    COUNTROWS(INTERSECT(TransacoesLinha, TransacoesColuna))
)
```

```dax
Purchased Both Products = 
VAR Result =
    IF(
        ISINSCOPE('dw DIM_PRODUTO'[produto_id]) &&
        ISINSCOPE('Comparação Produtos'[produto_id]),
        [Purchased Both Products (Cell)],
        SUMX(
            SUMMARIZECOLUMNS(
                'dw DIM_PRODUTO'[produto_id],
                'Comparação Produtos'[produto_id]
            ),
            [Purchased Both Products (Cell)]
        )
    )
RETURN Result
```

https://www.youtube.com/watch?v=VE0V_WhzFOI

https://www.youtube.com/watch?v=iZJz30LSik4

## Cohort

https://www.youtube.com/watch?v=vbg4Je1tuis

``dax
First Order Date = 
CALCULATE(
    MIN('dw FACT_VENDAS'[data_id]),
    ALLEXCEPT('dw FACT_VENDAS', 'dw FACT_VENDAS'[cliente_id])
)
```

## Time Intelligence (Vendas)

Assumindo que a tabela de datas `dw DIM_DATA` estA! marcada como Date Table e que o total bA!sico A(c):

```dax
Vendas Totais = SUM ( 'dw FACT_VENDAS'[valor_total] )
```

Medidas derivadas:

```dax
Vendas YTD =
TOTALYTD (
    [Vendas Totais],
    'dw DIM_DATA'[data]
)

Vendas Ano Anterior =
CALCULATE (
    [Vendas Totais],
    DATEADD ( 'dw DIM_DATA'[data], -1, YEAR )
)

Vendas Mes Anterior =
CALCULATE (
    [Vendas Totais],
    DATEADD ( 'dw DIM_DATA'[data], -1, MONTH )
)

Vendas Trimestre Anterior =
CALCULATE (
    [Vendas Totais],
    DATEADD ( 'dw DIM_DATA'[data], -1, QUARTER )
)

Crescimento YoY % =
DIVIDE ( [Vendas Totais] - [Vendas Ano Anterior], [Vendas Ano Anterior] )

Crescimento MoM % =
DIVIDE ( [Vendas Totais] - [Vendas Mes Anterior], [Vendas Mes Anterior] )

Media Movel 3M =
AVERAGEX (
    DATESINPERIOD ( 'dw DIM_DATA'[data], MAX ( 'dw DIM_DATA'[data] ), -3, MONTH ),
    [Vendas Totais]
)
```

Dicas de modelagem para evitar valores errados:
- Use sempre a coluna de datas da tabela de datas (nA#o a do fato) nos eixos/segmentadores.
- Garanta que nA#o hA! fendas de filtro removendo `dw DIM_DATA` (p.ex. com REMOVEFILTERS) antes de aplicar `DATEADD`.
- Se o modelo tiver vendas futuras, considere limitar as medidas a `<= TODAY()` para evitar distorA'is.
