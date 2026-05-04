-- Operazione 1 (Inserisci volo con successo)
/* implementata tramite la procedura inserisciVolo, che effettua
tutti i controlli necessari per il volo e inserisce la manutenzione
straordinaria se ci sono pezzi usurati */
CALL inserisciVolo('NEW001', 7, 'N197042');

-- Operazione 2 (Inserisci manutenzione straordinaria)
/* la differenza con l'operazione 1 sta nell'effetto: poiche il
pezzo con seriale 4 ha esaurito la sua vita utile in termini
di voli allora verra pianificata una manutenzione straordinaria 
e il volo non sara effettuato */
CALL inserisciVolo('NEW002', 3, 'N197042');

-- Operazione 3 (Effettua manutenzione straordinaria)
/* usiamo la procedura apposita, prende in input l'id dell'aereo
e il numero del tecnico che la esegue. La procedura trova i pezzi
di ricambio compatibili e li monta, altrimenti restituisce errore */
CALL esegui_manutenzione_straordinaria('N197042', 212043);
CALL esegui_manutenzione_straordinaria('N038010', 109037);

-- Operazione 4 (Effettua manutenzione ordinaria)
/* usiamo una procedura adattabile alle necessita, in questo caso
si sostituiscono i tre pezzi con vita rimasta in ore piu breve */
CALL esegui_manutenzione_ordinaria('N197042', '109037');

-- Operazione 5 (Inserisci pezzo)
INSERT INTO `Pezzo` (`id_componente`) VALUES (302), (502);

/* Operazione 6 (Stampa tutti gli aerei su cui sono state effettuate
manutenzioni in una settimana e le ore di volo nello stesso periodo) */
SELECT M.`id_aereo`, SUM(V.`durata`)
FROM `Manutenzione` M
JOIN `Volo` V ON M.`id_aereo` = V.`id_aereo`
WHERE M.`data` BETWEEN '2026-02-28 00:00:00' AND '2026-03-06 23:59:59'
AND V.`data` BETWEEN '2026-02-28 00:00:00' AND '2026-03-06 23:59:59'
GROUP BY M.`id_aereo`;

/* Operazione 7 (Stampa tutti i pezzi che sono stati installati e rimossi
nello stesso mese, indicando il codice del tecnico che li ha installati */
SELECT P.`Seriale`, M1.`data`, M2.`data`, M1.`id_tecnico`
FROM `Pezzo` P
JOIN `Manutenzione` M1 ON P.`installato` = M1.`ID`
JOIN `Manutenzione` M2 ON P.`rimosso` = M2.`ID`
WHERE (P.`installato` IS NOT NULL AND P.`rimosso` IS NOT NULL)
AND M1.`data` >= '2026-03-01 00:00:00'
AND M2.`data` <= '2026-03-31 23:59:59';
-- AND M2.`straordinaria` = TRUE

/* Operazione 8 (Stampa un elenco dove figurano le categorie di componenti
e il numero di installazioni ordinarie, straordinarie e totali.) */
SELECT 	
	C.`categoria`,
    SUM(CASE WHEN M.`straordinaria` = FALSE THEN 1 ELSE 0 END) AS inst_ordinarie,
    SUM(CASE WHEN M.`straordinaria` = TRUE THEN 1 ELSE 0 END) AS inst_straordinarie,
    COUNT(*) AS totali
FROM `Componente` C
JOIN `Pezzo` P ON C.`Codice` = P.`id_componente`
JOIN `Manutenzione` M ON P.`installato` = M.`ID`
WHERE P.`installato` IS NOT NULL
GROUP BY C.`categoria`
ORDER BY C.`categoria` ASC;