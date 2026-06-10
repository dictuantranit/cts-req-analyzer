/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_CustGroup`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_CustGroup`(
		IN	ip_Device 					JSON 
	,	IN	ip_AI    					JSON 
	,	IN	ip_IP    					JSON 
	,	IN	ip_SharedMatches 			JSON 
	,	IN	ip_SharedIP 				JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240415@Casey.Huynh
		Task :		Enhance Group Betting Match Monitor
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240610@Casey.Huynh: Created [Redmine ID: #203319]   
            - 	20250102@Thomas.Nguyen: Add more input param ip_SharedIP [Redmine ID: #214356]  

		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_Association_CustGroup_xpre(@ip_Device:='[{"O":1,"D":2},{"O":2,"D":3},{"O":4,"D":5}]'
            , @ip_AI:='[]'
            , @ip_IP:='[]'
            , @ip_SharedMatches:='[]');

	*/
    DECLARE lv_GroupID BIGINT UNSIGNED;
    DECLARE lv_OrigID BIGINT UNSIGNED;
    DECLARE lv_DestID BIGINT UNSIGNED;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE Temp_Association(
			OrigID 	BIGINT UNSIGNED
		,	DestID	BIGINT UNSIGNED
        ,	GroupID	INT
        
       ,	PRIMARY KEY PK_Temp_Association(OrigID,DestID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Group;
    CREATE TEMPORARY TABLE Temp_Group(
			NodeID 	BIGINT UNSIGNED
		,	GroupID	BIGINT UNSIGNED
        ,	PRIMARY KEY Temp_Group(NodeID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Graph;
    CREATE TEMPORARY TABLE Temp_Graph(
			OrigID 	BIGINT UNSIGNED
		,	DestID	BIGINT UNSIGNED
        ,	PRIMARY KEY Temp_Graph(OrigID,DestID)
	);

    SET lv_GroupID = 1;
    
    INSERT IGNORE INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.OrigID
		,	js.DestID
	FROM JSON_TABLE(ip_Device,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;
	
	INSERT INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.DestID
		,	js.OrigID
	FROM JSON_TABLE(ip_Device,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;

	INSERT IGNORE INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.OrigID
		,	js.DestID
	FROM JSON_TABLE(ip_AI,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;
						
	INSERT IGNORE INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.OrigID
		,	js.DestID
	FROM JSON_TABLE(ip_IP,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;
    
    INSERT IGNORE INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.OrigID
		,	js.DestID
	FROM JSON_TABLE(ip_SharedMatches,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;

	INSERT IGNORE INTO Temp_Graph(OrigID,DestID)
    SELECT 	js.OrigID
		,	js.DestID
	FROM JSON_TABLE(ip_SharedIP,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;
    
	INSERT IGNORE INTO Temp_Association(OrigID, DestID)
    SELECT	tmp.OrigID
		,	tmp.DestID
    FROM Temp_Graph AS tmp;    

    INSERT IGNORE INTO Temp_Association(OrigID, DestID)
    SELECT	tmp.DestID
		,	tmp.OrigID
    FROM Temp_Graph AS tmp;
    
    DROP TEMPORARY TABLE Temp_Graph;
    
	lp: LOOP 
		SET lv_OrigID = NULL;
        SET lv_DestID = NULL;
        
        SELECT tmp.OrigID, tmp.DestID
        INTO lv_OrigID, lv_DestID
		FROM Temp_Association AS tmp
        WHERE GroupID IS NULL
		LIMIT 1;
        
        IF lv_OrigID IS NULL 
        THEN 
            LEAVE lp; 
        END IF;
        
		INSERT IGNORE INTO Temp_Group(NodeID,GroupID)
		WITH RECURSIVE CTE_Group AS
		(
		  SELECT lv_OrigID AS OrigID
		  UNION
		  SELECT tmpAs.DestID AS OrigID
		  FROM Temp_Association AS tmpAs
			JOIN CTE_Group ON (CTE_Group.OrigID = tmpAs.OrigID) 
          WHERE tmpAs.GroupID IS  NULL
		)
        SELECT OrigID, lv_GroupID FROM CTE_Group;
		
		UPDATE Temp_Association AS tmpAs
        INNER JOIN Temp_Group tmpGr ON tmpGr.NodeID = tmpAs.OrigID
        SET tmpAs.GroupID = lv_GroupID
        WHERE tmpAs.GroupID IS NULL; 
        
        SET lv_GroupID = lv_GroupID + 1;
	END LOOP;

    SELECT 	tmpGr.NodeID
		,	tmpGr.GroupID
    FROM Temp_Group AS tmpGr;
END$$
DELIMITER ;
