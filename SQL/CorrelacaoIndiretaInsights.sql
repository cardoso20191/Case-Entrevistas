--1.1 CORRELAÇÃO - entre base_nomes e base_uf
--Junção pelo cpf anonimo

SELECT
	n.cpf_anonimo,
	n.primeiro_nome,
	n.renda,
	u.ultimo_nome,
	u.uf,
	u.orgsup_lotacao_instituidor_pensao
FROM base_nome n
INNER JOIN base_uf u
	ON n.cpf_anonimo = u.cpf_anonimo;

-----------------------------------------------------------
--1.2 Correlação indireta com base_geral (agregada por UF)
-- Comparar a distribuição de UFs ebtre bases sen expor os indivíduos.

SELECT 	uf,
	COUNT(*) AS qtd_base_geral
FROM base_geral
GROUP BY uf
ORDER BY qtd_base_geral DESC;

-----------------------------------------------------------
--1.2.1 Comparando com base_uf

SELECT 	uf,
	COUNT(*) AS qtd_base_uf
FROM base_uf
GROUP BY uf
ORDER BY qtd_base_uf DESC;

-----------------------------------------------------------
--1.2.3 Cruzamento dos dois SELECT para gerar um único resultado
-- Isso gera divergências estatistica entre as bases, sem precisar correlacionar CPF

SELECT
	g.uf,
	g.qtd_base_geral,
	u.qtd_base_uf,
	(u.qtd_base_uf - g.qtd_base_geral) AS divergencia
FROM (
	SELECT uf, COUNT(*) AS qtd_base_geral FROM base_geral GROUP BY uf) g
FULL JOIN (
	SELECT uf, COUNT(*) AS qtd_base_uf FROM base_uf GROUP BY uf) u
	ON g.uf = u.uf;

-----------------------------------------------------------
--2 Correlacionando perfil e renda - sem reidentificação

SELECT u.uf,
	AVG(n.renda) AS renda_media
FROM base_nome n
INNER JOIN base_uf u
	ON n.cpf_anonimo = u.cpf_anonimo
GROUP BY u.uf;

-----------------------------------------------------------
--2.1 Renda categorizada por grupo correlacionado base_nome

SELECT faixa_renda, COUNT(*) AS total
FROM ( SELECT
	CASE
		WHEN renda < 2000 THEN 'Baixa Renda (<2k)'
		WHEN renda BETWEEN 2001 AND 6000 THEN 'Classe Média Baixa (2-6k)'
		WHEN renda > 6001 THEN 'Alta Renda (>6k)'
	END AS faixa_renda
FROM base_nome) t
GROUP BY faixa_renda
ORDER BY total DESC;

-----------------------------------------------------------
--2.1 Correlacionando Idade média por UF

SELECT uf,
	AVG(DATEDIFF(YEAR, dt_nascimento, GETDATE())) AS idade_media
FROM base_geral
GROUP BY uf;

-----------------------------------------------------------
--3 Correlação indireta final (renda média x idade média)

WITH renda_por_uf AS (
	SELECT u.uf,
		AVG(n.renda) AS renda_media
	FROM base_nome n
	INNER JOIN base_uf u
		ON n.cpf_anonimo = u.cpf_anonimo
	GROUP BY u.uf),
idade_por_uf AS (
	SELECT uf,
	AVG(DATEDIFF(YEAR, dt_nascimento, GETDATE())) AS idade_media
	FROM base_geral
	GROUP BY uf
)
SELECT
	r.uf,
	r.renda_media,
	i.idade_media
FROM renda_por_uf r
INNER JOIN idade_por_uf i
	ON r.uf = i.uf;

-----------------------------------------------------------
--3.1 Correlação indireta base_nome e base_geral - agrupado por região

WITH renda_por_uf AS (
	SELECT 
		u.uf,
		AVG(n.renda) AS renda_media
	FROM base_nome n
	INNER JOIN base_uf u
		ON n.cpf_anonimo = u.cpf_anonimo
	GROUP BY u.uf
),
idade_por_uf AS (
	SELECT 
		uf,
		AVG(DATEDIFF(YEAR, dt_nascimento, GETDATE())) AS idade_media
	FROM base_geral
	GROUP BY uf
),
regiao_uf AS (
	SELECT 
		uf,
		CASE 
			WHEN uf IN ('SP','RJ','MG','ES') THEN 'Sudeste'
			WHEN uf IN ('PR','SC','RS') THEN 'Sul'
			WHEN uf IN ('MT','MS','GO','DF') THEN 'Centro-Oeste'
			WHEN uf IN ('BA','SE','AL','PE','PB','RN','CE','PI','MA') THEN 'Nordeste'
			ELSE 'Norte'
		END AS regiao
	FROM base_geral
	GROUP BY uf
)

SELECT 
	rg.regiao,
	AVG(r.renda_media) AS renda_media_regiao,
	AVG(i.idade_media) AS idade_media_regiao
FROM regiao_uf rg
LEFT JOIN renda_por_uf r ON r.uf = rg.uf
LEFT JOIN idade_por_uf i ON i.uf = rg.uf
GROUP BY rg.regiao
ORDER BY renda_media_regiao DESC;
