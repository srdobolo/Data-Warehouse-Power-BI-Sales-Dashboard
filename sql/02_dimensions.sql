USE [SalesDW];
GO
SET LANGUAGE Portuguese; -- Define a linguagem para português para nomes de meses e dias da semana
SET NOCOUNT ON; -- Evita mensagens desnecessárias de contagem de linhas afetadas

DROP TABLE IF EXISTS dw.DIM_DATA;
DROP TABLE IF EXISTS dw.DIM_LOJA;
DROP TABLE IF EXISTS dw.DIM_CLIENTE;
DROP TABLE IF EXISTS dw.DIM_PRODUTO;
GO

CREATE TABLE dw.DIM_DATA (
    data_id     INT IDENTITY(1,1) PRIMARY KEY,
    data        DATE        NOT NULL UNIQUE,
    ano         INT         NOT NULL,
    trimestre   CHAR(2)     NOT NULL,
    mes         VARCHAR(15) NOT NULL,
    dia_semana  VARCHAR(15) NOT NULL
);

WITH todas_as_datas AS (
    SELECT v.data_venda AS data_ref
    FROM staging.vendas AS v
    WHERE v.data_venda IS NOT NULL

    UNION

    SELECT c.data_registo
    FROM staging.clientes AS c
    WHERE c.data_registo IS NOT NULL
)
INSERT INTO dw.DIM_DATA (data, ano, trimestre, mes, dia_semana)
SELECT DISTINCT
       d.data_ref,
       YEAR(d.data_ref),
       CONCAT('T', DATEPART(QUARTER, d.data_ref)),
       DATENAME(MONTH, d.data_ref),
       DATENAME(WEEKDAY, d.data_ref)
FROM todas_as_datas AS d;

CREATE TABLE dw.DIM_LOJA (
    loja_id   INT PRIMARY KEY,
    nome      NVARCHAR(150) NOT NULL,
    cidade    NVARCHAR(80)  NOT NULL,
    distrito  NVARCHAR(80)  NOT NULL,
    regiao    NVARCHAR(80)  NOT NULL,
    tipo      NVARCHAR(30)  NOT NULL
);

INSERT INTO dw.DIM_LOJA
SELECT DISTINCT
       loja_id, nome, cidade, distrito, regiao, tipo
FROM staging.lojas;

CREATE TABLE dw.DIM_CLIENTE (
    cliente_id    INT PRIMARY KEY,
    nome          NVARCHAR(200) NULL,
    email         NVARCHAR(200) NULL,
    telefone      NVARCHAR(50)  NULL,
    genero        CHAR(1)       NULL,
    loja_id       INT           NULL,
    cidade        NVARCHAR(80)  NULL,
    distrito      NVARCHAR(80)  NULL,
    regiao        NVARCHAR(80)  NULL,
    tipo_loja     NVARCHAR(30)  NULL,
    faixa_etaria  VARCHAR(20)   NOT NULL,
    data_registo  DATE          NULL
);

WITH clientes_union AS (
    SELECT
        c.cliente_id,
        c.nome,
        c.email,
        c.telefone,
        c.genero,
        c.loja_id,
        c.idade,
        c.data_registo
    FROM staging.clientes AS c

    UNION ALL

    SELECT DISTINCT
        v.cliente_id,
        CAST(NULL AS NVARCHAR(200)) AS nome,
        CAST(NULL AS NVARCHAR(200)) AS email,
        CAST(NULL AS NVARCHAR(50)) AS telefone,
        CAST(NULL AS CHAR(1)) AS genero,
        CAST(NULL AS INT) AS loja_id,
        CAST(NULL AS INT) AS idade,
        CAST(NULL AS DATE) AS data_registo
    FROM staging.vendas AS v
    WHERE NOT EXISTS (
        SELECT 1
        FROM staging.clientes AS c
        WHERE c.cliente_id = v.cliente_id
    )
)
INSERT INTO dw.DIM_CLIENTE (
    cliente_id,
    nome,
    email,
    telefone,
    genero,
    loja_id,
    cidade,
    distrito,
    regiao,
    tipo_loja,
    faixa_etaria,
    data_registo
)
SELECT DISTINCT
       cu.cliente_id,
       cu.nome,
        cu.email,
        cu.telefone,
       cu.genero,
       cu.loja_id,
       l.cidade,
       l.distrito,
       l.regiao,
       l.tipo AS tipo_loja,
       CASE
            WHEN cu.idade IS NULL THEN 'Desconhecido'
            WHEN cu.idade < 25 THEN '<25'
            WHEN cu.idade BETWEEN 25 AND 34 THEN '25-34'
            WHEN cu.idade BETWEEN 35 AND 44 THEN '35-44'
            WHEN cu.idade BETWEEN 45 AND 54 THEN '45-54'
            WHEN cu.idade BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
       END AS faixa_etaria,
       cu.data_registo
FROM clientes_union AS cu
LEFT JOIN staging.lojas AS l
       ON l.loja_id = cu.loja_id;

CREATE TABLE dw.DIM_PRODUTO (
    produto_id        INT PRIMARY KEY,
    nome              NVARCHAR(200) NOT NULL,
    categoria         NVARCHAR(100) NOT NULL,
    subcategoria      NVARCHAR(100) NOT NULL,
    marca             NVARCHAR(80)  NOT NULL,
    margem_percentual DECIMAL(6,2)  NOT NULL,
    preco_venda       DECIMAL(18,2) NOT NULL,
    custo             DECIMAL(18,2) NOT NULL
);

INSERT INTO dw.DIM_PRODUTO
SELECT DISTINCT
       produto_id,
       nome,
       categoria,
       subcategoria,
       marca,
       margem_percentual,
       preco_venda,
       custo
FROM staging.produtos;
GO
