# Sales Data Warehouse

Este repositório documenta a construção de um mini data warehouse para a cadeia fictícia **TechSolutions**, cobrindo a geração do dataset de retalho, a orquestração de infraestrutura em Docker, o ETL Python e a modelagem dimensional em SQL Server. O objetivo final é disponibilizar dados consistentes para análises em Power BI.

## Estrutura do Repositório

- `data/` &mdash; geração e armazenamento dos CSVs (script `10804Proj3.py`, ficheiros `clientes`, `lojas`, `produtos`, `vendas`).
- `docker/` &mdash; `docker-compose.yml` mais Dockerfiles para o SQL Server e container loader, além do `.env` com variáveis.
- `etl/` &mdash; script `ingest_csv.py` que percorre os CSVs e faz o *load* para staging em MSSQL.
- `sql/` &mdash; scripts `00_init_schema.sql` até `03_facts.sql` que criam a base DW e alimentam dimensões/factos, e `queries/` com exemplos.
- `powerbi/` &mdash; ficheiro `.pbix` de referência para dashboards.

## Geração de Dados Sintéticos

1. Instale as dependências Python (é necessário `faker`, `pandas`, etc.).
2. Execute `python data/10804Proj3.py`.  
   O script cria 20 lojas, 1 564 clientes, 200 produtos e ~1,3M vendas de 2020-2025, guardando tudo em `data/*.csv` com encoding UTF-8.
3. Os campos já incluem métricas financeiras como `preco_unitario`, `desconto_percentual`, `custo_unitario` e `valor_total`, simplificando a criação do fact table.

## Infraestrutura & Preparação

1. **Configurar `.env`** em `docker/.env` (senha SA, nome da BD `SalesDW`, paths dentro do container).
2. **Subir os contêineres** a partir de `docker/`:
   ```bash
   docker compose up -d --build
   ```
   - Serviço `mssql`: SQL Server 2022 exposto na porta informada.
   - Serviço `loader`: ambiente Python conectado via volumes a `data/`, `etl/` e `sql/`.
3. **Instalar dependências no loader**:
   ```bash
   docker compose exec loader pip install -r etl/requirements.txt
   ```

## ETL de Alto Nível

1. **Gerar dados** (`python data/10804Proj3.py`).  
2. **Ingestão para staging**: no container loader execute `python etl/ingest_csv.py`.  
   - O script cria a BD (`SalesDW`) se necessário, varre todos os CSVs de `DATA_PATH` e grava cada ficheiro em tabelas `staging.*` com `pandas.to_sql`.  
   - Após a carga, `staging.lojas`, `staging.clientes`, `staging.produtos` e `staging.vendas` estão disponíveis para transformação.
3. **Construção do DW**: rode sequencialmente os scripts em `sql/` (via SSMS, Azure Data Studio ou `sqlcmd`):
   1. `00_init_schema.sql` &mdash; garante a existência da base `SalesDW` e dos schemas `staging` e `dw`.
   2. `01_staging.sql` &mdash; recria staging com tipos corretos e índices (`data_venda`, `loja_id`, `cliente_id`, `produto_id`). Quando o OLTP estiver num servidor separado, basta trocar `SalesDB` pelo nome da origem.
   3. `02_dimensions.sql` &mdash; gera todas as dimensões finais, lidando com chaves naturais/surrogate e preenchendo dados faltantes (p. ex. clientes sem cadastro herdados das vendas recebem faixa etária “Desconhecido”).
   4. `03_facts.sql` &mdash; monta `dw.FACT_VENDAS` ao relacionar staging com as dimensões, recalculando `valor_total` se necessário.
4. **Validação/queries**: execute `sql/queries/queries.sql` para obter métricas básicas (receita diária, top produtos, etc.) ou conecte o Power BI diretamente ao SQL Server.

## Modelagem do Data Warehouse

### Modelo Conceitual

Entidades principais e relacionamentos (cardinalidade 1:N):

- **Loja** fornece contexto geográfico (região, distrito, tipo) e relaciona-se com várias vendas.
- **Cliente** descreve perfil demográfico básico e também é origem para factos de venda.
- **Produto** define categoria/subcategoria/marca e métricas de margem.
- **Data** representa o calendário corporativo com granulação diária.
- **Venda** é o evento central conectando loja, cliente, produto e data.

### Modelo Lógico (Dimensional)

| Tabela            | Chave | Atributos principais |
|-------------------|-------|----------------------|
| `DIM_DATA`        | `data_id` (surrogate) | `data`, `ano`, `trimestre`, `mes`, `dia_semana` |
| `DIM_LOJA`        | `loja_id` (natural)   | `nome`, `cidade`, `distrito`, `regiao`, `tipo` |
| `DIM_CLIENTE`     | `cliente_id` (natural) | `genero`, `loja_id` de origem, `faixa_etaria`, `data_registo` |
| `DIM_PRODUTO`     | `produto_id` (natural) | `nome`, `categoria`, `subcategoria`, `marca`, `margem_percentual`, `preco_venda`, `custo` |
| `FACT_VENDAS`     | `venda_id` | FKs (`data_id`, `loja_id`, `cliente_id`, `produto_id`) + métricas (`quantidade`, `preco_unitario`, `desconto_pct`, `custo_unitario`, `valor_total`) |

### Modelo Relacional

- Todos os objetos residem na BD `SalesDW`.  
- Schema `staging` contém as tabelas de origem carregadas via ETL (`staging.lojas`, `staging.clientes`, `staging.produtos`, `staging.vendas`).  
- Schema `dw` mantém as tabelas dimensionais e o fact table. As colunas e restrições físicas seguem os scripts em `sql/02_dimensions.sql` e `sql/03_facts.sql`.

### Modelo Físico

- **DB**: SQL Server 2022 (`SalesDW`).  
- **Schemas**: `staging` para *landing zone* e `dw` para o modelo em estrela.  
- **Estruturas**:
  - `dw.DIM_DATA` usa `IDENTITY(1,1)` e índice único em (`data`).  
  - `dw.DIM_LOJA`, `dw.DIM_CLIENTE`, `dw.DIM_PRODUTO` preservam IDs naturais vindos do OLTP, simplificando integrações com sistemas externos.  
  - `dw.FACT_VENDAS` utiliza `BIGINT` para `venda_id` e FKs estritas.  
  - Índices em `staging.vendas` aceleram *lookups* durante o `INSERT` do fato, e o fact table pode receber índices adicionais (por exemplo `NONCLUSTERED` em (`data_id`, `loja_id`)).

## Execução de Consultas e Dashboards

- `sql/queries/queries.sql` contém *snippets* para:
  - Receita agregada por ano/trimestre.
  - Top produtos por margem.
  - Desempenho por região/loja.
- No Power BI, conecte-se a `SalesDW`, relate `dw.FACT_VENDAS` com cada dimensão e crie hierarquias (por exemplo `DIM_DATA`: `Ano > Trimestre > Mês > Data`). O ficheiro `Dashboard.pbix` mostra um exemplo de consumo.

## Próximos Passos Sugeridos

1. Automatizar o pipeline num *Makefile* ou workflow CI/CD (`docker compose up`, ingestão, execução de scripts SQL).  
2. Adicionar testes ou validações automáticas (contagens de linhas, checksums) após cada etapa do ETL.  
3. Expandir o modelo com fatos agregados diários e dimensões adicionais (ex.: campanhas, canais de venda) caso o negócio cresça.
