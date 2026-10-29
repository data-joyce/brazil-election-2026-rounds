-- BRAZIL 2026 PRESIDENTIAL ELECTION: FIRST ROUND (4 OCT) VS SECOND ROUND (25 OCT)
-- Database: turnos_2026.db (SQLite), built with 01_load_data.sql
-- Source: TSE (Brazil's Electoral Court), Open Data Portal, files downloaded on 27/10/2026
--   detalhe_votacao_secao_2026_BR   -> table detalhe_secao (turnout, blank and null votes per section, both rounds)
--   votacao_partido_munzona_2026_BR -> table votos_partido (votes for each candidate per city + zone, both rounds)
--   candidatos -> a small table i made by hand with the number and name of each candidate
--
-- My questions:
-- 1) How many people could vote, how many voted, and how many votes each candidate got in each round?
-- 2) Are the totals the same in both rounds?
-- 3) Where did Lula's extra votes in round 2 come from?
--
-- One important thing before i start: the vote is secret, so i DON'T know who each person voted for.
-- What i can show are the totals going up and down between the rounds, and where (region, state, zone).
--
-- Small glossary, because the TSE columns and my table columns are in Portuguese:
--
-- | TSE column                  | My column      | English                                            |
-- |-----------------------------|----------------|----------------------------------------------------|
-- | NR_TURNO                    | turno          | round (1 or 2)                                     |
-- | SG_UF                       | uf             | state (ZZ = voters abroad)                         |
-- | CD_MUNICIPIO / NM_MUNICIPIO | cd_municipio / | city code / city name                              |
-- |                             | municipio      |                                                    |
-- | NR_ZONA                     | zona           | electoral zone (a group of sections)               |
-- | NR_SECAO                    | secao          | section (one ballot box)                           |
-- | QT_APTOS                    | aptos          | eligible voters                                    |
-- | QT_COMPARECIMENTO           | comparecimento | people who voted (turnout)                         |
-- | QT_ABSTENCOES               | abstencoes     | people who didn't vote (abstention)                |
-- | QT_VOTOS_NOMINAIS           | votos_nominais | votes typed for a candidate number                 |
-- | QT_VOTOS_BRANCOS            | brancos        | blank votes                                        |
-- | QT_VOTOS_NULOS              | nulos          | null (spoiled) votes                               |
-- | ST_SECAO_INSTALADA          | instalada      | did the section have a ballot box? (Sim/Não)       |
-- | NR_PARTIDO                  | numero         | party number (= candidate number for president)    |
-- | QT_VOTOS_NOMINAIS_VALIDOS   | votos_validos  | valid votes for the candidate                      |
-- | QT_VOTOS_NULOS_TECNICOS     | (see query 4)  | "technical null" votes: typed for a candidate      |
-- |                             |                | whose registration was not valid                   |
--
-- Other Portuguese words in the data: candidato = candidate, regiao = region, Sim = yes, Não = no,
-- Norte / Nordeste / Centro-Oeste / Sudeste / Sul = North / Northeast / Center-West / Southeast / South, Exterior = abroad


-- PART 1: THE BASIC NUMBERS

-- 1. HOW MANY PEOPLE COULD VOTE IN EACH ROUND
-- i add up the eligible voters of every section, in Brazil and abroad
SELECT turno AS round,
       SUM(aptos) AS eligible_voters
FROM detalhe_secao
GROUP BY turno; -- 158,745,502 in both rounds, same voters

-- 2. VOTES FOR EACH CANDIDATE IN EACH ROUND
-- i join the votes with the names and add up the votes of each candidate
-- the percentage is based on valid votes (blank and null don't count), the same way the TSE does it
-- SUM(...) OVER (PARTITION BY turno) gives me the total of valid votes of each round, to divide by
SELECT votos.turno AS round,
       candidatos.nome AS candidate,
       SUM(votos.votos_validos) AS votes,
       ROUND(100.0 * SUM(votos.votos_validos)
             / SUM(SUM(votos.votos_validos)) OVER (PARTITION BY votos.turno), 2) AS perc_valid
FROM votos_partido AS votos
JOIN candidatos USING (numero)
GROUP BY votos.turno, candidatos.nome
HAVING SUM(votos.votos_validos) > 0
ORDER BY votos.turno, votes DESC; -- round 1: Flávio 56,104,503 (47.03%) vs Lula 53,879,538 (45.16%)
                                  -- round 2: Lula 64,256,232 (51.79%) vs Flávio 59,826,041 (48.21%)

-- 3. WHO VOTED, WHO DIDN'T, BLANK AND NULL VOTES IN EACH ROUND
-- i add up each column per round and calculate turnout and abstention based on eligible voters
SELECT turno AS round,
       SUM(comparecimento) AS voted,
       SUM(abstencoes) AS did_not_vote,
       SUM(brancos) AS blank,
       SUM(nulos) AS null_votes,
       SUM(votos_nominais) AS candidate_votes,
       ROUND(100.0 * SUM(comparecimento) / SUM(aptos), 2) AS perc_turnout,
       ROUND(100.0 * SUM(abstencoes) / SUM(aptos), 2) AS perc_abstention
FROM detalhe_secao
GROUP BY turno; -- round 1: 125,275,835 voted, 33,469,244 didn't, 2,300,798 blank, 3,669,003 null
                -- round 2: 128,236,074 voted, 30,509,005 didn't, 1,430,496 blank, 2,723,305 null

-- 4. CHECK: VOTES TYPED FOR A CANDIDATE VS VALID VOTES
-- the section file says how many votes were typed for a candidate number (votos_nominais)
-- the party file says how many of those votes were valid (votos_validos)
-- they should be the same, so i compare them in each round
SELECT secoes.turno AS round,
       secoes.votos_nominais AS candidate_votes,
       partidos.votos_validos AS valid_votes,
       secoes.votos_nominais - partidos.votos_validos AS technical_null
FROM (SELECT turno, SUM(votos_nominais) AS votos_nominais FROM detalhe_secao GROUP BY turno) AS secoes
JOIN (SELECT turno, SUM(votos_validos) AS votos_validos FROM votos_partido GROUP BY turno) AS partidos
    USING (turno); -- 5,246 in round 1, 0 in round 2
-- These 5,246 votes went to Leonardo Araujo (28, PRTB). His registration was not valid, so the TSE counts them
-- as "technical null" votes (column QT_VOTOS_NULOS_TECNICOS in the detalhe_votacao_munzona file).
-- So i add them to the null votes, not to the valid votes.
-- Total null votes in round 1 = 3,669,003 + 5,246 = 3,674,249

-- 5. CHECK: VOTED + DIDN'T VOTE = ELIGIBLE VOTERS?
-- if everything adds up, the difference should be zero
SELECT turno AS round,
       SUM(aptos) - SUM(comparecimento) - SUM(abstencoes) AS difference
FROM detalhe_secao
GROUP BY turno; -- 423 in both rounds
-- Let's see where these 423 people are: i look for sections without a ballot box
SELECT turno AS round,
       COUNT(*) AS sections,
       SUM(aptos) AS eligible_voters
FROM detalhe_secao
WHERE instalada = 'Não'
GROUP BY turno; -- 41 sections abroad with no ballot box; the TSE counts 0 voted and 0 abstained there, so it's not an error


-- PART 2: WHERE DID LULA'S EXTRA VOTES COME FROM?

-- 6. ONE ROW PER CITY + ZONE, WITH BOTH ROUNDS SIDE BY SIDE
-- i need this because the votes file is per city + zone, not per section
-- so first i add up the sections of each zone (CTE detalhe), then the votes of each zone (CTE votos), and then i join them
-- column names: 1 = round 1, 2 = round 2, comp = people who voted, bn = blank + null votes
CREATE TABLE zona_turnos AS
WITH detalhe AS (
    SELECT uf,
           CAST(cd_municipio AS INT) AS cd_municipio,
           municipio,
           zona,
           SUM(CASE
                   WHEN turno = 1 THEN aptos
               END) AS aptos,
           SUM(CASE
                   WHEN turno = 1 THEN comparecimento
               END) AS comp1,
           SUM(CASE
                   WHEN turno = 2 THEN comparecimento
               END) AS comp2,
           SUM(CASE
                   WHEN turno = 1 THEN brancos + nulos
               END) AS brancos_nulos1,
           SUM(CASE
                   WHEN turno = 2 THEN brancos + nulos
               END) AS brancos_nulos2,
           SUM(CASE
                   WHEN turno = 1 THEN votos_nominais
               END) AS nominais1,
           SUM(CASE
                   WHEN turno = 2 THEN votos_nominais
               END) AS nominais2
    FROM detalhe_secao
    GROUP BY 1, 2, 3, 4
),
votos AS (
    SELECT uf,
           cd_municipio,
           zona,
           SUM(CASE
                   WHEN turno = 1 THEN votos_validos
                   ELSE 0
               END) AS validos1,
           SUM(CASE
                   WHEN turno = 2 THEN votos_validos
                   ELSE 0
               END) AS validos2,
           SUM(CASE
                   WHEN turno = 1 AND numero = 13 THEN votos_validos
                   ELSE 0
               END) AS lula1,
           SUM(CASE
                   WHEN turno = 2 AND numero = 13 THEN votos_validos
                   ELSE 0
               END) AS lula2,
           SUM(CASE
                   WHEN turno = 1 AND numero = 22 THEN votos_validos
                   ELSE 0
               END) AS flavio1,
           SUM(CASE
                   WHEN turno = 2 AND numero = 22 THEN votos_validos
                   ELSE 0
               END) AS flavio2,
           SUM(CASE
                   WHEN turno = 1 AND numero = 70 THEN votos_validos
                   ELSE 0
               END) AS cury1,
           SUM(CASE
                   WHEN turno = 1 AND numero = 14 THEN votos_validos
                   ELSE 0
               END) AS renan1,
           SUM(CASE
                   WHEN turno = 1 AND numero = 55 THEN votos_validos
                   ELSE 0
               END) AS caiado1
    FROM votos_partido
    GROUP BY 1, 2, 3
)
SELECT detalhe.uf, detalhe.cd_municipio, detalhe.municipio, detalhe.zona, detalhe.aptos,
       detalhe.comp1, detalhe.comp2,
       -- blank + null + technical null (see query 4)
       detalhe.brancos_nulos1 + (detalhe.nominais1 - votos.validos1) AS bn1,
       detalhe.brancos_nulos2 + (detalhe.nominais2 - votos.validos2) AS bn2,
       votos.lula1, votos.lula2, votos.flavio1, votos.flavio2,
       votos.cury1, votos.renan1, votos.caiado1,
       -- all the other small candidates together, e.g. Zema and Samara
       votos.validos1 - votos.lula1 - votos.flavio1 - votos.cury1 - votos.renan1 - votos.caiado1 AS outros1
FROM detalhe
LEFT JOIN votos USING (uf, cd_municipio, zona);

-- i check that every zone found its votes
SELECT COUNT(*) AS zones,
       SUM(lula1 IS NULL) AS zones_without_votes
FROM zona_turnos; -- 6,292 rows, all of them found their votes
-- note: 41 cities abroad show zero votes (40 had no ballot box + 1 where nobody voted). this doesn't change any total

-- 7. THE BIG PICTURE: WHERE CAN THE NEW VOTES COME FROM?
-- In round 2 there were only 2 names on the ballot. So their extra votes can only come from:
-- people who voted for another candidate, people who voted blank/null before, or people who didn't vote before
SELECT SUM(lula2 - lula1) AS lula_gain,
       SUM(flavio2 - flavio1) AS flavio_gain,
       SUM(cury1 + renan1 + caiado1 + outros1) AS other_candidates_votes,
       SUM(bn1 - bn2) AS fewer_blank_null,
       SUM(comp2 - comp1) AS more_voters
FROM zona_turnos; -- Lula +10,376,694 / Flávio +3,721,538 = 14,098,232
                  -- = 9,316,747 other candidates + 1,821,246 fewer blank/null + 2,960,239 more voters. it matches exactly

-- 8. GAIN BY REGION
-- i turn each state into its region with CASE, add up each finalist's gain,
-- and calculate Lula's share of valid votes in each round
SELECT CASE
           WHEN uf IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'Norte'
           WHEN uf IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste'
           WHEN uf IN ('DF','GO','MT','MS') THEN 'Centro-Oeste'
           WHEN uf IN ('ES','MG','RJ','SP') THEN 'Sudeste'
           WHEN uf IN ('PR','RS','SC') THEN 'Sul'
           ELSE 'Exterior'
       END AS region,
       SUM(lula2 - lula1) AS lula_gain,
       SUM(flavio2 - flavio1) AS flavio_gain,
       ROUND(100.0 * SUM(lula1) / SUM(lula1 + flavio1 + cury1 + renan1 + caiado1 + outros1), 1) AS perc_lula_round1,
       ROUND(100.0 * SUM(lula2) / SUM(lula2 + flavio2), 1) AS perc_lula_round2
FROM zona_turnos
GROUP BY 1
ORDER BY lula_gain DESC; -- Southeast +4.8 million (SP alone +2.6 million), Northeast +3.0 million. almost half came from the Southeast

-- 9. ZONES GROUPED BY THE STRONGEST "THIRD" CANDIDATE
-- for each zone in Brazil, i check who got more votes in round 1 among Cury, Renan and Caiado
-- then i add up the finalists' gain in each group and calculate how much went to Lula
WITH zonas AS (
    SELECT *,
           CASE
               WHEN cury1 >= renan1 AND cury1 >= caiado1 THEN 'Augusto Cury'
               WHEN renan1 >= caiado1 THEN 'Renan Santos'
               ELSE 'Ronaldo Caiado'
           END AS strongest_third
    FROM zona_turnos
    WHERE uf <> 'ZZ'
)
SELECT strongest_third,
       COUNT(*) AS zones,
       SUM(lula2 - lula1) AS lula_gain,
       SUM(flavio2 - flavio1) AS flavio_gain,
       ROUND(100.0 * SUM(lula2 - lula1) / SUM(lula2 - lula1 + flavio2 - flavio1), 1) AS perc_lula_of_gain
FROM zonas
GROUP BY 1
ORDER BY zones DESC; -- Cury zones: Lula got 76.4% of the new votes; Renan zones 64.4%; Caiado zones 63.6%
                     -- in all 4,740 Cury zones, Cury was in 3rd place

-- 10. GAIN BY STATE
-- the same math as query 7, one row per state (ZZ = abroad)
SELECT uf AS state,
       SUM(lula2 - lula1) AS lula_gain,
       SUM(flavio2 - flavio1) AS flavio_gain,
       SUM(cury1 + renan1 + caiado1 + outros1) AS other_candidates_votes,
       SUM(bn1 - bn2) AS fewer_blank_null,
       SUM(comp2 - comp1) AS more_voters
FROM zona_turnos
GROUP BY uf
ORDER BY lula_gain DESC; -- SP leads (+2.6 million for Lula). Lula gained votes in every state
                         -- Flávio lost votes in AC, AM, AP, MA, RR and TO; turnout went down in 9 states (North, MA and PI)

-- 11. ZONES GROUPED BY THE CHANGE IN TURNOUT
-- i calculate how many percentage points the turnout changed in each zone and put the zones in 4 groups
WITH zonas AS (
    SELECT *,
           100.0 * (comp2 - comp1) / aptos AS turnout_change
    FROM zona_turnos
    WHERE uf <> 'ZZ'
)
SELECT CASE
           WHEN turnout_change < 0 THEN 'a. went down'
           WHEN turnout_change < 2 THEN 'b. up 0 to 2 points'
           WHEN turnout_change < 4 THEN 'c. up 2 to 4 points'
           ELSE 'd. up 4 points or more'
       END AS turnout_group,
       COUNT(*) AS zones,
       SUM(comp2 - comp1) AS more_voters,
       SUM(lula2 - lula1) AS lula_gain,
       SUM(flavio2 - flavio1) AS flavio_gain
FROM zonas
GROUP BY 1; -- most of Lula's gain (6.1 million) came from the 2,611 zones where turnout went up 2 to 4 points
