DROP DATABASE IF EXISTS `compagnia_aerea`;
CREATE DATABASE `compagnia_aerea`;
USE `compagnia_aerea`;


CREATE TABLE `Tecnico` (
	`ID_cert` INT PRIMARY KEY,
    `CF` VARCHAR(16) UNIQUE NOT NULL,
    `nome` varchar(30) NOT NULL,
    `cognome` varchar(30) NOT NULL
);

CREATE TABLE `Modello` (
	`Codice` VARCHAR(5) PRIMARY KEY,
    `posti` SMALLINT
);

CREATE TABLE `Componente` (
	`Codice` SMALLINT PRIMARY KEY,
    `lim_ore` INT NOT NULL,
    `lim_voli` INT NOT NULL,
    `categoria` TINYINT NOT NULL CHECK (`categoria` BETWEEN 1 AND 5)
);

CREATE TABLE `Requisito` (
	`id_modello` VARCHAR(5),
    `id_componente` SMALLINT,
    `obbligatorio` BOOL NOT NULL,
    PRIMARY KEY (`id_modello`, `id_componente`),
    FOREIGN KEY (`id_modello`) REFERENCES `Modello`(`Codice`),
    FOREIGN KEY (`id_componente`) REFERENCES `Componente`(`Codice`)
);

CREATE TABLE `Aereo` (
	`Registrazione` VARCHAR(10) PRIMARY KEY,
    `data_inizio` TIMESTAMP DEFAULT NULL,
    `data_fine` TIMESTAMP DEFAULT NULL,
    `id_modello` VARCHAR(5) NOT NULL,
    FOREIGN KEY (`id_modello`) REFERENCES `Modello`(`Codice`),
    CONSTRAINT 
		CHECK( (`data_inizio` IS NULL AND `data_fine` IS NULL)
			OR (`data_inizio` IS NOT NULL) )
);

CREATE TABLE `Volo` (
	`Numero` VARCHAR(10) PRIMARY KEY,
    `durata` INT NOT NULL,
    `data` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    `id_aereo` VARCHAR(10) NOT NULL,
    FOREIGN KEY (`id_aereo`) REFERENCES `Aereo`(`Registrazione`)
);

CREATE TABLE `Manutenzione` (
	`ID` INT AUTO_INCREMENT PRIMARY KEY,
    `data` TIMESTAMP DEFAULT NULL,
    `straordinaria` BOOL NOT NULL,
    `id_aereo` VARCHAR(10) NOT NULL,
    `id_tecnico` INT DEFAULT NULL,
    FOREIGN KEY (`id_aereo`) REFERENCES `Aereo`(`Registrazione`),
    FOREIGN KEY (`id_tecnico`) REFERENCES `Tecnico`(`ID_cert`),
    CONSTRAINT 
		CHECK( (`id_tecnico` IS NULL AND `data` IS NULL)
			OR (`id_tecnico` IS NOT NULL AND `data` IS NOT NULL) )
);

CREATE TABLE `Pezzo` (
	`Seriale` INT AUTO_INCREMENT PRIMARY KEY,
    `obbligatorio` BOOL DEFAULT NULL,
	`ore_rim` INT DEFAULT NULL,
    `voli_rim` INT DEFAULT NULL,
    `id_componente` SMALLINT NOT NULL,
    `id_aereo` VARCHAR(10) DEFAULT NULL,
    `installato` INT DEFAULT NULL,
    `rimosso` INT DEFAULT NULL,
    FOREIGN KEY (`id_componente`) REFERENCES `Componente`(`Codice`),
    FOREIGN KEY (`id_aereo`) REFERENCES `Aereo`(`Registrazione`),
    FOREIGN KEY (`installato`) REFERENCES `Manutenzione`(`ID`),
    FOREIGN KEY (`rimosso`) REFERENCES `Manutenzione`(`ID`),
    CONSTRAINT 
		CHECK( (`installato` IS NULL AND `rimosso` IS NULL AND `id_aereo` IS NULL)
			OR (`installato` IS NOT NULL AND `rimosso` IS NULL AND `id_aereo` IS NOT NULL)
            OR (`installato` IS NOT NULL AND `rimosso` IS NOT NULL AND `id_aereo` IS NULL) )
);


DELIMITER //

-- Controlla se l'aereo e in servizio
CREATE FUNCTION inServizio(id_aereo VARCHAR(10))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE num INT;
    SELECT COUNT(*) INTO num
		FROM `Aereo`
		WHERE `Registrazione` = id_aereo
		AND (`data_inizio` IS NOT NULL AND `data_fine` IS NULL);
    RETURN (num > 0);
END //

-- Controlla se ci sono manutenzioni straordinarie da effettuare
CREATE FUNCTION haManutenzioni(aereo VARCHAR(10))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE num INT;
    SELECT COUNT(*) INTO num
		FROM `Manutenzione`
		WHERE `id_aereo` = aereo
		AND `straordinaria` = TRUE
		AND (`data` IS NULL OR `id_tecnico` IS NULL);
    RETURN (num > 0);
END //

-- Controlla se sono presenti tutti i pezzi obbligatori
CREATE FUNCTION tuttiPezzi(aereo VARCHAR(10))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE numR INT;
    DECLARE numP INT;
    SELECT DISTINCT COUNT(*) INTO numR
		FROM `Aereo` A
		JOIN `Requisito` R ON A.`id_modello` = R.`id_modello` 
		WHERE A.`Registrazione` = aereo
		AND R.`obbligatorio` = TRUE;
    SELECT DISTINCT COUNT(*) INTO numP
		FROM `Pezzo`
		WHERE `id_aereo` = aereo
		AND `obbligatorio` = TRUE;
    RETURN (numR = numP);
END //

-- Controlla se ci sono pezzi usurati
CREATE FUNCTION pezziOk(aereo VARCHAR(10))
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE num INT;
    SELECT COUNT(*) INTO num
		FROM `Pezzo`
		WHERE `id_aereo` = aereo
		AND `obbligatorio` = TRUE
		AND (`ore_rim` <= 0 OR `voli_rim` <= 0);
    RETURN (num = 0);
END //

DELIMITER ;


DELIMITER //

-- Controlla che non ci sia gia quel componente installato e che sia compatibile 
CREATE TRIGGER validaInstallazioneUpdate
BEFORE UPDATE ON `Pezzo`
FOR EACH ROW
BEGIN
    IF NEW.installato IS NOT NULL AND OLD.installato IS NULL THEN
		IF EXISTS (
			SELECT 1
				FROM `Pezzo`
				WHERE `id_aereo` = NEW.id_aereo
				AND `id_aereo` IS NOT NULL
				AND `id_componente` = NEW.id_componente 
				AND `Seriale` != NEW.Seriale
		) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente gia installato';
		ELSEIF NOT EXISTS (
			SELECT 1 
				FROM `Requisito` R
				JOIN `Aereo` A ON A.`id_modello` = R.`id_modello`
				WHERE A.`Registrazione` = NEW.id_aereo
				AND R.`id_componente` = NEW.id_componente
        ) THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente non compatibile';
        END IF;
    END IF;
END //

-- Uguale al precedente ma con INSERT
CREATE TRIGGER validaInstallazioneInsert
BEFORE INSERT ON `Pezzo`
FOR EACH ROW
BEGIN
    IF NEW.installato IS NOT NULL THEN
		IF EXISTS (
			SELECT 1
				FROM `Pezzo`
				WHERE `id_aereo` = NEW.id_aereo
				AND `id_aereo` IS NOT NULL
				AND `id_componente` = NEW.id_componente 
				AND `Seriale` != NEW.Seriale
		) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente gia installato';
		ELSEIF NOT EXISTS (
			SELECT 1 
				FROM `Requisito` R
				JOIN `Aereo` A ON A.`id_modello` = R.`id_modello`
				WHERE A.`Registrazione` = NEW.id_aereo
				AND R.`id_componente` = NEW.id_componente
        ) THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Componente non compatibile';
        END IF;
    END IF;
END //

-- Controlla che durante la manutenzione sia stato svolto almeno un intervento
CREATE TRIGGER validaManutenzioneUpdate
BEFORE UPDATE ON `Manutenzione`
FOR EACH ROW
BEGIN
    IF NEW.`id_tecnico` IS NOT NULL AND OLD.`id_tecnico` IS NULL THEN
		IF NOT EXISTS (
			SELECT 1 FROM `Pezzo` WHERE `installato` = NEW.`ID` OR `rimosso` = NEW.`ID`
		) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nessun intervento eseguito';
        END IF;
    END IF;
END //

-- Uguale al precedente ma con INSERT
CREATE TRIGGER validaManutenzioneInsert
BEFORE INSERT ON `Manutenzione`
FOR EACH ROW
BEGIN
    IF NEW.`id_tecnico` IS NOT NULL THEN
		IF NOT EXISTS (
			SELECT 1 FROM `Pezzo` WHERE `installato` = NEW.`ID` OR `rimosso` = NEW.`ID`
		) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nessun intervento eseguito';
        END IF;
    END IF;
END // 

DELIMITER ;


DELIMITER //

/* 
Quando si inserisce un volo dobbiamo effettuare i seguenti passaggi:
	1) effettuare i controlli su i dati per verificare che ci siano le condizioni minime
	2) inserire la manutenzione se ci sono pezzi usurati e annullare il volo
	3) inserire il volo e aggiornare la durata dei pezzi
Inizialmente e stato implementato un mix di trigger e funzioni (non si possono usare le procedure
all'interno di un trigger) ma si verificava il seguente problema: il caso in cui si inserisce la 
manutenzione non dava un risultato corretto perche se l'operazione veniva interrotta con SIGNAL SQLSTATE
la manutenzione non veniva salvata, mentre se non veniva interrotta non si poteva eliminare il volo 
perche MySQL impedisce al trigger di modificare la tabella che l'ha invocato.
Dunque si e scelto di implementare una singola procedure che includa tutte e tre le funzionalita,
quando si vuole inserire un volo basta chiamare la procedura con gli stessi parametri necessari
nel semplice INSERT, semplificando la logica di questa operazione.
*/
CREATE PROCEDURE inserisciVolo(IN in_volo VARCHAR(10), IN in_durata INT, IN in_aereo VARCHAR(10))
BEGIN
    DECLARE manutenzione_id INT;
    IF NOT inServizio(in_aereo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Aereo non in servizio.';
    ELSEIF haManutenzioni(in_aereo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Manutenzioni non completate.';
    ELSEIF NOT tuttiPezzi(in_aereo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Componenti obbligatori mancanti.';
    ELSEIF NOT pezziOk(in_aereo) THEN
		START TRANSACTION;
        INSERT INTO `Manutenzione` (`id_aereo`, `straordinaria`) VALUES (in_aereo, TRUE);
        SET manutenzione_id = LAST_INSERT_ID();
        UPDATE `Pezzo`
			SET `id_aereo` = NULL, `rimosso` = manutenzione_id
			WHERE `id_aereo` = in_aereo
			AND `obbligatorio` = TRUE
			AND (`ore_rim` <= 0 OR `voli_rim` <= 0);
		COMMIT;
    ELSE
		START TRANSACTION;
        INSERT INTO `Volo` (`Numero`, `durata`, `id_aereo`) VALUES (in_volo, in_durata, in_aereo);
        UPDATE `Pezzo`
			SET `ore_rim` = `ore_rim` - in_durata, `voli_rim` = `voli_rim` - 1
			WHERE `id_aereo` = in_aereo;
		COMMIT;
    END IF;
END //


/* La procedura completa una manutenzione straordinaria gia programmata e durante la quale i
pezzi sono gia stati rimossi, quindi per prima cosa si trova la manutenzione attiva, poi si
trovano tutti i pezzi che sono stati rimossi e si ottiene un elenco dei componenti per cui
si deve trovare un pezzo di ricambio, si chiama poi la procedura che fa cio e installa i pezzi
di ricambio trovati, per poi completare la manutenzione. */
CREATE PROCEDURE esegui_manutenzione_straordinaria(IN in_aereo VARCHAR(10), IN in_tecnico INT)
BEGIN
    DECLARE manutenzione_id INT;
	
    IF NOT inServizio(in_aereo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Aereo non in servizio.';
	END IF;
        
    -- Crea una tabella temporanea dove vengono salvati i componenti da sostituire
    DROP TEMPORARY TABLE IF EXISTS `temp_componenti_da_sostituire`;
    CREATE TEMPORARY TABLE `temp_componenti_da_sostituire` (`id_componente` SMALLINT);
    
    -- Trova la manutenzione straordinaria attiva per l'aereo
    SELECT M.`ID` INTO manutenzione_id
		FROM `Manutenzione` M
		WHERE M.`id_aereo` = in_aereo
		AND M.`straordinaria` = TRUE
		AND (M.`id_tecnico` IS NULL AND M.`data` IS NULL)
		LIMIT 1;
	IF (manutenzione_id IS NULL) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Nessuna manutenzione straordinaria.';
    END IF;
    
    -- Trova i componenti da sostiutire nella manutenzione
    INSERT INTO `temp_componenti_da_sostituire`
		SELECT P.`id_componente`
			FROM `Pezzo` P
			WHERE P.`rimosso` = manutenzione_id
			AND P.`rimosso` IS NOT NULL;

    -- Installa i pezzi di ricambio e completa la manutenzione
    CALL installa_ricambi(in_aereo, in_tecnico, manutenzione_id);

    -- Cancella la tabella temporanea
    DROP TEMPORARY TABLE IF EXISTS `temp_componenti_da_sostituire`;
END //


/* La procedura comincia una nuova manutenzione ordinaria, individua i tre pezzi installati con
la vita rimasta in ore minore e li aggiunge all'elenco dei componenti da sostituire per poi rimuoverli,
viene chiamata poi la funzione che cerca i pezzi di ricambio, li installa e completa la manutenzione. */
CREATE PROCEDURE esegui_manutenzione_ordinaria(IN in_aereo VARCHAR(10), IN in_tecnico INT)
BEGIN
    DECLARE manutenzione_id INT;
    
    IF NOT inServizio(in_aereo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Aereo non in servizio.';
	END IF;
	
    -- Crea una tabella temporanea dove vengono salvati i componenti da sostituire
    DROP TEMPORARY TABLE IF EXISTS `temp_componenti_da_sostituire`;
    CREATE TEMPORARY TABLE `temp_componenti_da_sostituire` (`id_componente` SMALLINT);
    
    START TRANSACTION;
    
		-- Inizia una manutenzione ordinaria
		INSERT INTO `Manutenzione` (`data`, `straordinaria`, `id_aereo`, `id_tecnico`)
			VALUES (NULL, FALSE, in_aereo, NULL);
		SET manutenzione_id = LAST_INSERT_ID();
		
		-- Trova i tre pezzi installati con la vita in ore piu breve
		INSERT INTO `temp_componenti_da_sostituire`
			SELECT `id_componente`
				FROM `Pezzo`
				WHERE `ore_rim` IS NOT NULL
				AND `id_aereo` = in_aereo
				ORDER BY `ore_rim` ASC
				LIMIT 3;
				
		-- Smonta i pezzi da sostituire
		UPDATE `Pezzo` P
			SET P.`id_aereo` = NULL, P.`rimosso` = manutenzione_id
			WHERE P.`id_aereo` = in_aereo
			AND P.`id_componente` IN (
				SELECT TCS.`id_componente`
				FROM  `temp_componenti_da_sostituire` TCS
			);

		-- Installa i pezzi di ricambio e completa la manutenzione
		CALL installa_ricambi(in_aereo, in_tecnico, manutenzione_id);

	COMMIT;

    -- Cancella la tabella temporanea
    DROP TEMPORARY TABLE IF EXISTS `temp_componenti_da_sostituire`;
END //


/* La procedura prende la tabella temporanea che contiene i componenti da sostituire, trova dei pezzi
di ricambio compatibili e se ci sono tutti li installa e completa la manutenzione. */
CREATE PROCEDURE installa_ricambi(IN in_aereo VARCHAR(10), IN in_tecnico INT, IN manutenzione_id INT)
BEGIN
	-- Si ha la tebella temp_componenti_da_sostituire con tutti i componenti da sostituire
	
    -- Crea una tabella temporanea dove vengono salvati i pezzi da installare
    DROP TEMPORARY TABLE IF EXISTS `temp_pezzi_da_installare`;
    CREATE TEMPORARY TABLE `temp_pezzi_da_installare`(`Seriale` INT);
    
    -- Trova un pezzo per ogni tipo di componente da installare
    INSERT INTO `temp_pezzi_da_installare`
		SELECT P.`Seriale`
			FROM `temp_componenti_da_sostituire` TCS
			LEFT JOIN `Pezzo` P ON TCS.`id_componente` = P.`id_componente`
			WHERE P.`Seriale` = (
				SELECT P2.`Seriale`
					FROM `Pezzo` P2
					WHERE P2.`id_componente` = TCS.`id_componente`
					AND (P2.`id_aereo` IS NULL AND P2.`installato` IS NULL)
					LIMIT 1
			);
    -- Se mancano pezzi di ricambio restituisce errore
    IF EXISTS (
        SELECT 1
			FROM `temp_componenti_da_sostituire` TCS
			WHERE TCS.`id_componente` NOT IN (
				SELECT P.`id_componente`
					FROM `temp_pezzi_da_installare` TPI
					JOIN `Pezzo` P ON TPI.`Seriale` = P.`Seriale`
			)
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Parti di ricambio mancanti.';
    END IF;
    
    START TRANSACTION;
    
		-- Monta i pezzi sull'aereo
		UPDATE `Pezzo` P
			SET P.`id_aereo` = in_aereo, 
				P.`installato` = manutenzione_id,
                P.`ore_rim` = (SELECT C.`lim_ore` FROM `Componente` C WHERE C.`Codice` = P.`id_componente` LIMIT 1),
				P.`voli_rim` = (SELECT C.`lim_voli` FROM `Componente` C WHERE C.`Codice` = P.`id_componente` LIMIT 1),
                P.`obbligatorio` = (
					SELECT R.`obbligatorio`
						FROM `Requisito` R
                        JOIN `Aereo` A ON R.`id_modello` = A.`id_modello`
                        WHERE A.`Registrazione` = in_aereo
                        AND R.`id_componente` = P.`id_componente`
                        LIMIT 1
				)
			WHERE P.`Seriale` IN (SELECT TPI.`Seriale` FROM `temp_pezzi_da_installare` TPI);
		
		-- Completa la manutenzione
		UPDATE `Manutenzione`
			SET `data` = CURRENT_TIMESTAMP, `id_tecnico` = in_tecnico
			WHERE `ID` = manutenzione_id;
            
	COMMIT;
	
    -- Cancella la tabella temporanea
	DROP TEMPORARY TABLE IF EXISTS `temp_pezzi_da_installare`;
END //


DELIMITER ;


START TRANSACTION;

	INSERT INTO `Modello` (`Codice`, `posti`)
	VALUES
		('B747', 660),
		('A380', 615),
        ('B777', 480);

	INSERT INTO `Aereo` (`Registrazione`, `data_inizio`, `id_modello`)
	VALUES
		('N197042', CURRENT_TIMESTAMP, 'B747'),
		('N038010', CURRENT_TIMESTAMP, 'A380'),
        ('N80085L', NULL, 'B777');
		
	INSERT INTO `Tecnico` (`ID_cert`, `CF`, `nome`, `cognome`)
	VALUES
		(109037, 'MRARSS81T21C351P', 'Mario', 'Rossi'),
		(212043, 'PPPTNG69B31G371S', 'Pippo', 'Tango');
		
	INSERT INTO `Componente` (`Codice`, `lim_ore`, `lim_voli`, `categoria`)
	VALUES
		(101, 25, 3, 1),
		(102, 12, 4, 1),
		(201, 74, 5, 2),
		(301, 102, 8, 3),
		(302, 118, 7, 4),
		(401, 231, 4, 4),
		(501, 129, 7, 5),
		(502, 125, 10, 5);
		
	INSERT INTO `Requisito` (`id_modello`, `id_componente`, `obbligatorio`)
	VALUES
		('B747', 101, TRUE),
		('B747', 201, FALSE),
		('B747', 301, FALSE),
		('B747', 401, TRUE),
		('B747', 501, FALSE),
		('A380', 102, TRUE),
		('A380', 301, TRUE),
		('A380', 302, FALSE),
		('A380', 401, FALSE),
		('A380', 502, FALSE);

	INSERT INTO `Manutenzione` (`data`, `straordinaria`, `id_aereo`, `id_tecnico`)
	VALUES
		(NULL, FALSE, 'N197042', NULL),
		(NULL, FALSE, 'N038010', NULL);
	
	INSERT INTO `Pezzo` (`obbligatorio`, `ore_rim`, `voli_rim`, `id_componente`, `id_aereo`, `installato`)
	VALUES
		(NULL, NULL, NULL, 101, NULL, NULL),
        (NULL, NULL, NULL, 301, NULL, NULL),
        (NULL, NULL, NULL, 401, NULL, NULL),
		(TRUE, 25, 3, 101, 'N197042', 1),
		(FALSE, 74, 5, 201, 'N197042', 1),
		(FALSE, 102, 8, 301, 'N197042', 1),
		(TRUE, 231, 4, 401, 'N197042', 1),
		(FALSE, 129, 7, 501, 'N197042', 1),
		(TRUE, 12, 4, 102, 'N038010', 2),
		(TRUE, 102, 8, 301, 'N038010', 2),
		(FALSE, 118, 7, 302, 'N038010', 2),
		(FALSE, 231, 4, 401, 'N038010', 2),
		(FALSE, 125, 10, 502, 'N038010', 2),
        (NULL, NULL, NULL, 101, NULL, NULL),
        (NULL, NULL, NULL, 102, NULL, NULL),
        (NULL, NULL, NULL, 201, NULL, NULL);
        
	UPDATE `Manutenzione` SET `data` = CURRENT_TIMESTAMP, `id_tecnico` = 212043 WHERE `ID` = 1;
    UPDATE `Manutenzione` SET `data` = CURRENT_TIMESTAMP, `id_tecnico` = 109037 WHERE `ID` = 2;
  
COMMIT;

START TRANSACTION;
	CALL inserisciVolo('PRV123', 3, 'N197042'); -- OK -> puo volare ancora
	CALL inserisciVolo('TST666', 13, 'N038010'); -- OK -> non puo volare ancora 
	CALL inserisciVolo('TST667', 13, 'N038010'); -- NO -> inserisce manutenzione 
/*	CALL inserisciVolo('TST668', 13, 'N038010'); -- ERRORE manutenzione non eseguita */
    CALL inserisciVolo('PRV111', 5, 'N197042'); -- OK, ma se avviene l'errore ^^^ non viene chiamata
COMMIT;