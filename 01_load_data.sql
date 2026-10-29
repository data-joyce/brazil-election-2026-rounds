-- BRAZIL 2026 PRESIDENTIAL ELECTION: LOADING THE TSE FILES INTO SQLITE
-- This file runs in the sqlite3 command line (it uses .import), not in DBeaver:
--   sqlite3 turnos_2026.db < 01_load_data.sql
--
-- Before running it, i downloaded 2 files from the TSE Open Data Portal (https://dadosabertos.tse.jus.br/):
--   detalhe_votacao_secao_2026.zip   -> i used only detalhe_votacao_secao_2026_BR.csv (president, both rounds)
--   votacao_partido_munzona_2026.zip -> i used only votacao_partido_munzona_2026_BR.csv (president, both rounds)
-- The TSE files are latin1 and use ";" as separator, so first i converted them to UTF-8:
--   iconv -f latin1 -t utf-8 detalhe_votacao_secao_2026_BR.csv > detalhe.csv
--   iconv -f latin1 -t utf-8 votacao_partido_munzona_2026_BR.csv > partido.csv


-- 1. IMPORT THE RAW FILES
-- everything comes in as text, so i import into raw tables first and fix the types after
.mode csv
.separator ";"
.import detalhe.csv raw_detalhe
.import partido.csv raw_partido


-- 2. TURNOUT, BLANK AND NULL VOTES PER SECTION, BOTH ROUNDS
-- i kept only the columns i need and gave them short names (glossary in 02_analysis.sql)
CREATE TABLE detalhe_secao AS
SELECT CAST(NR_TURNO AS INT) AS turno,
       SG_UF AS uf,
       CD_MUNICIPIO AS cd_municipio,
       NM_MUNICIPIO AS municipio,
       CAST(NR_ZONA AS INT) AS zona,
       CAST(NR_SECAO AS INT) AS secao,
       CAST(QT_APTOS AS INT) AS aptos,
       CAST(QT_COMPARECIMENTO AS INT) AS comparecimento,
       CAST(QT_ABSTENCOES AS INT) AS abstencoes,
       CAST(QT_VOTOS_NOMINAIS AS INT) AS votos_nominais,
       CAST(QT_VOTOS_BRANCOS AS INT) AS brancos,
       CAST(QT_VOTOS_NULOS AS INT) AS nulos,
       CAST(QT_VOTOS_LEGENDA AS INT) AS legenda,
       CAST(QT_VOTOS_ANULADOS_APU_SEP AS INT) AS anulados_sep,
       ST_SECAO_INSTALADA AS instalada,
       ST_SECAO_ANULADA AS anulada,
       DS_ORIGEM_VOTO AS origem
FROM raw_detalhe; -- 499,248 sections in each round


-- 3. VOTES FOR EACH CANDIDATE PER CITY + ZONE, BOTH ROUNDS
-- for president each party has only 1 candidate, so party number = candidate number
CREATE TABLE votos_partido AS
SELECT CAST(NR_TURNO AS INT) AS turno,
       SG_UF AS uf,
       CAST(CD_MUNICIPIO AS INT) AS cd_municipio,
       NM_MUNICIPIO AS municipio,
       CAST(NR_ZONA AS INT) AS zona,
       CAST(NR_PARTIDO AS INT) AS numero,
       SG_PARTIDO AS partido,
       ST_VOTO_EM_TRANSITO AS transito,
       CAST(QT_VOTOS_NOMINAIS_VALIDOS AS INT) AS votos_validos,
       CAST(QT_TOTAL_VOTOS_LEG_VALIDOS AS INT) AS votos_legenda,
       CAST(QT_VOTOS_NOMINAIS_ANULADOS AS INT) AS anulados,
       CAST(QT_VOTOS_NOMINAIS_ANUL_SUBJUD AS INT) AS anul_subjud
FROM raw_partido; -- 75,504 rows in round 1 (12 candidates) and 12,584 in round 2 (2 candidates)

DROP TABLE raw_detalhe;
DROP TABLE raw_partido;


-- 4. CANDIDATE NAMES
-- the party file only has the party, so i made a small table with the names by hand
-- (names checked in the votacao_secao_2026_BR file, column NM_VOTAVEL)
CREATE TABLE candidatos (numero INT, nome TEXT);
INSERT INTO candidatos VALUES
    (13, 'Lula (PT)'),
    (14, 'Renan Santos'),
    (16, 'Hertz Dias'),
    (21, 'Edmilson Costa'),
    (22, 'Flávio Bolsonaro (PL)'),
    (27, 'Clariana Barão'),
    (28, 'Leonardo Araujo'),
    (29, 'Rui Costa Pimenta'),
    (30, 'Romeu Zema (NOVO)'),
    (35, 'Wilson Grassi Junior'),
    (55, 'Ronaldo Caiado (PSD)'),
    (70, 'Augusto Cury'),
    (80, 'Samara Feitosa');
