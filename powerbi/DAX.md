## Medidas DAX obrigatórias

As medidas abaixo seguem os requisitos do documento `[10804]Projeto3.pdf` (pág. 6). As tabelas mantêm os nomes importados do SQL Server (`dw FACT_VENDAS`, `dw DIM_DATA`, `dw DIM_PRODUTO`, etc.).

### Medidas base

```DAX
Vendas Totais =
SUM ( 'dw FACT_VENDAS'[valor_total] )
```

```DAX
Quantidade Vendida =
SUM ( 'dw FACT_VENDAS'[quantidade] )
```

```DAX
Numero de Transacoes =
DISTINCTCOUNT ( 'dw FACT_VENDAS'[venda_id] )
```

```DAX
Transacao Media =
DIVIDE ( [Vendas Totais], [Numero de Transacoes] )
```

```DAX
Margem de Lucro =
SUMX (
    'dw FACT_VENDAS',
    'dw FACT_VENDAS'[quantidade]
        * ( 'dw FACT_VENDAS'[preco_unitario] - 'dw FACT_VENDAS'[custo_unitario] )
)
```

### Time intelligence

```DAX
Vendas Ano Anterior =
CALCULATE ( [Vendas Totais], DATEADD ( 'dw DIM_DATA'[data], -1, YEAR ) )
```

```DAX
Crescimento YoY % =
VAR Atual = [Vendas Totais]
VAR Anterior = [Vendas Ano Anterior]
RETURN DIVIDE ( Atual - Anterior, Anterior )
```

```DAX
Vendas Mes Anterior =
CALCULATE ( [Vendas Totais], DATEADD ( 'dw DIM_DATA'[data], -1, MONTH ) )
```

```DAX
Crescimento MoM % =
VAR Atual = [Vendas Totais]
VAR Anterior = [Vendas Mes Anterior]
RETURN DIVIDE ( Atual - Anterior, Anterior )
```

```DAX
Vendas YTD =
TOTALYTD ( [Vendas Totais], 'dw DIM_DATA'[data] )
```

```DAX
Vendas Trimestre Anterior =
CALCULATE ( [Vendas Totais], DATEADD ( 'dw DIM_DATA'[data], -1, QUARTER ) )
```

```DAX
Crescimento QoQ % =
VAR Atual = [Vendas Totais]
VAR Anterior = [Vendas Trimestre Anterior]
RETURN DIVIDE ( Atual - Anterior, Anterior )
```

```DAX
Vendas Periodo Anterior :=
VAR PeriodoAnterior =
    PREVIOUSPERIOD ( 'dw DIM_DATA'[data] )
RETURN
    CALCULATE ( [Vendas Totais], PeriodoAnterior )
```

```DAX
Media Movel 3M =
AVERAGEX (
    DATESINPERIOD ( 'dw DIM_DATA'[data], MAX ( 'dw DIM_DATA'[data] ), -3, MONTH ),
    [Vendas Totais]
)
```

### Desempenho

```DAX
Ranking Produtos =
RANKX (
    ALL ( 'dw DIM_PRODUTO'[produto_id] ),
    [Vendas Totais],
    ,
    DESC,
    DENSE
)
```

```DAX
Contribuicao Percentual =
VAR TotalContexto =
    CALCULATE ( [Vendas Totais], ALLSELECTED ( 'dw FACT_VENDAS' ) )
RETURN
    DIVIDE ( [Vendas Totais], TotalContexto )
```

```DAX
Taxa de Crescimento =
VAR Anterior = [Vendas Periodo Anterior]
RETURN DIVIDE ( [Vendas Totais] - Anterior, Anterior )
```

```DAX
Pareto 80/20 Acumulado =
VAR TabelaProdutos =
    ADDCOLUMNS (
        ALL ( 'dw DIM_PRODUTO'[produto_id] ),
        "@VendasProduto", CALCULATE ( [Vendas Totais] )
    )
VAR RankingAtual =
    RANKX ( TabelaProdutos, [@VendasProduto], CALCULATE ( [Vendas Totais] ), DESC, DENSE )
VAR TotalVendas = SUMX ( TabelaProdutos, [@VendasProduto] )
VAR VendasAcumuladas =
    SUMX (
        TOPN ( RankingAtual, TabelaProdutos, [@VendasProduto], DESC ),
        [@VendasProduto]
    )
RETURN
    DIVIDE ( VendasAcumuladas, TotalVendas )
```

```DAX
Pareto 80/20 Classe =
IF ( [Pareto 80/20 Acumulado] <= 0.8, "Top 80%", "Restante 20%" )
```
