/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_Details_MergeGroup`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_Details_MergeGroup`(
		IN ip_TransList		JSON       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230105@Casey.Huynh
		Task :		CTS_DC_MatchMonitor_Details_MergeReasonGroup
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230222@Casey.Huynh: Created [Redmine ID: 181995]
			- 	20240105@Casey.Huynh: Exclude Lopsided Bet [Redmine ID: 197706]
            - 	20240327@Casey.Huynh: Fix PK Temp_ExcludeTrans [Redmine ID: 202972]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_Details_MergeGroup(@ip_TransList:='[
					{"TransID":87310633518759936,"ScoreDiff":1,"Reason":0,"GroupID":4,"Betteam":"a","CustID":1267}
				,	{"TransID":87310689353334784,"ScoreDiff":1,"Reason":0,"GroupID":4,"Betteam":"a","CustID":1261}
				,	{"TransID":87310994296012800,"ScoreDiff":1,"Reason":0,"GroupID":6,"Betteam":"h","CustID":1265}
				,	{"TransID":87311045835620352,"ScoreDiff":1,"Reason":0,"GroupID":6,"Betteam":"h","CustID":1267}
				]');

	*/
    DECLARE CONST_REASON_FIXEDGAME INT DEFAULT 3;
    DECLARE CONST_REASON_LOPSIDEDBETTING INT DEFAULT 4;
    
	DECLARE lv_MergeGroupID INT;
    DECLARE lv_GroupID BIGINT UNSIGNED;
    DECLARE lv_TransID BIGINT UNSIGNED;
    DECLARE lv_CustID BIGINT UNSIGNED;
    DECLARE lv_Betteam VARCHAR(10);
    DECLARE lv_MaxKey INT;

    DROP TEMPORARY TABLE IF EXISTS Temp_TransGroup;
    CREATE TEMPORARY TABLE Temp_TransGroup
    (
			TransID 			BIGINT UNSIGNED
		,	ScoreDiff 			INT
        ,	Reason 				INT
        ,	GroupID 			BIGINT UNSIGNED
        ,	Betteam				VARCHAR(10) 
        ,	CustID				BIGINT UNSIGNED
        ,	KeyTransID			BIGINT UNSIGNED 
        ,	KeyGroupID			BIGINT UNSIGNED 
        ,	KeyCustIDBetteam	BIGINT UNSIGNED 
        ,	GroupTrans			INT
        ,	MergeGroupID		INT
        ,	PRIMARY KEY PK_Temp_TransGroupID(GroupID,TransID)
		,	INDEX IX_Temp_Key_TransGroup_TransID(TransID)
        ,	INDEX IX_Temp_Key_TransGroup_CustIDBetteam(CustID,Betteam)
    );    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ExcludeTrans;
	CREATE TEMPORARY TABLE Temp_ExcludeTrans(
			TransID BIGINT UNSIGNED
		,	ScoreDiff INT
        ,	Reason	INT
        ,	GroupID BIGINT UNSIGNED
        ,	PRIMARY KEY PK_Temp_ExcludeTrans_ReasonTransID(Reason,TransID)
	);   
	
	INSERT IGNORE INTO Temp_TransGroup(TransID, ScoreDiff, Reason, GroupID, Betteam, CustID)
	SELECT  js.TransID
		,	js.ScoreDiff
		,	js.Reason
		,	js.GroupID
		,	js.Betteam
		,	js.CustID
	FROM JSON_TABLE(ip_TransList,
					 "$[*]" COLUMNS(
								TransID			BIGINT UNSIGNED PATH "$.TransID" 
							,	ScoreDiff		INT PATH "$.ScoreDiff" 
							,	Reason			INT PATH "$.Reason" 
							,	GroupID			BIGINT UNSIGNED PATH "$.GroupID"
							,	Betteam			VARCHAR(10) PATH "$.Betteam" 
							,	CustID			BIGINT UNSIGNED PATH "$.CustID" 
						)
				) AS js;
    
    #===========EXCLUDE "FIXED GAME" WHEN MERG GROUP===========
    INSERT IGNORE INTO Temp_ExcludeTrans(TransID, Reason, ScoreDiff, GroupID)
    SELECT tmpTg.TransID, tmpTg.Reason, tmpTg.ScoreDiff, GroupID
    FROM Temp_TransGroup AS tmpTg
    WHERE Reason IN (CONST_REASON_FIXEDGAME,CONST_REASON_LOPSIDEDBETTING);

    DELETE tmpTg
    FROM Temp_TransGroup AS tmpTg
    WHERE tmpTg.Reason IN (CONST_REASON_FIXEDGAME,CONST_REASON_LOPSIDEDBETTING);  
    #==================================================
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
	CREATE TEMPORARY TABLE 		Temp_Group (
			TransID 			BIGINT UNSIGNED
		,	CustID				BIGINT UNSIGNED
        ,	Betteam				VARCHAR(10)
		,	GroupID 			BIGINT UNSIGNED
		,	INDEX			    IX_Temp_Group(GroupID)
	);
    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Input;
    CREATE TEMPORARY TABLE Temp_Input(
			FromID 	BIGINT UNSIGNED
		,	ToID	BIGINT UNSIGNED
        ,	PRIMARY KEY PK_Temp_Association(FromID,ToID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Key_TransGroup;
    CREATE TEMPORARY TABLE Temp_Key_TransGroup(
			ID 		BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY
		,	TransID	BIGINT UNSIGNED 
        ,	GroupID	BIGINT UNSIGNED
        ,	CustID	BIGINT UNSIGNED        
        ,	Betteam	VARCHAR(10)
        
        ,	INDEX IX_Temp_Key_TransGroup_TransID(TransID)
        ,	INDEX IX_Temp_Key_TransGroup_GroupID(GroupID)
        ,	INDEX IX_Temp_Key_TransGroup_CustIDBetteam(CustID,Betteam)
	);
    
    #================================================================================
    INSERT INTO Temp_Key_TransGroup(TransID)
    SELECT DISTINCT TransID
    FROM Temp_TransGroup;
    
    INSERT INTO Temp_Key_TransGroup(GroupID)
    SELECT DISTINCT GroupID
    FROM Temp_TransGroup;
    
    INSERT INTO Temp_Key_TransGroup(CustID, Betteam)
    SELECT DISTINCT CustID, Betteam
    FROM Temp_TransGroup;    

	UPDATE Temp_TransGroup AS tmpTg
    INNER JOIN Temp_Key_TransGroup AS tmpK ON tmpTg.TransID = tmpK.TransID
    SET tmpTg.KeyTransID = tmpK.ID;
    
    UPDATE Temp_TransGroup AS tmpTg
    INNER JOIN Temp_Key_TransGroup AS tmpK ON tmpTg.GroupID = tmpK.GroupID
    SET tmpTg.KeyGroupID = tmpK.ID;
    
    UPDATE Temp_TransGroup AS tmpTg
    INNER JOIN Temp_Key_TransGroup AS tmpK ON tmpTg.CustID = tmpK.CustID and tmpTg.Betteam = tmpK.Betteam
    SET tmpTg.KeyCustIDBetteam = tmpK.ID;
    
	#====================MERGE GROUP BY TransID====================
    
    INSERT INTO Temp_Input(FromID, ToID)
    SELECT DISTINCT KeyTransID, KeyGroupID
    FROM Temp_TransGroup;
    
    CALL CTS_DC_Common_AssociationGroup();
        
    SET lv_MaxKey = (SELECT MAX(ID) FROM Temp_Key_TransGroup);

    UPDATE Temp_TransGroup tmpTg
    INNER JOIN Temp_Association AS tmpAs ON tmpTg.KeyTransID = tmpAs.FromID
    SET tmpTg.GroupTrans = tmpAs.GroupID + lv_MaxKey;
	
    #====================MERGE GROUP BY CustID AND Betteam====================
    TRUNCATE TABLE Temp_Input;
    INSERT INTO Temp_Input(FromID, ToID)
	SELECT DISTINCT KeyCustIDBetteam, GroupTrans
    FROM Temp_TransGroup;    
    
	CALL CTS_DC_Common_AssociationGroup();

    UPDATE Temp_TransGroup tmpTg
    INNER JOIN Temp_Association AS tmpAs ON tmpTg.KeyCustIDBetteam = tmpAs.FromID
    SET tmpTg.MergeGroupID = tmpAs.GroupID;  
	
    #================================================================

    INSERT INTO Temp_TransGroup(TransID, Reason, ScoreDiff, GroupID)
    SELECT TransID, Reason, ScoreDiff, GroupID
    FROM Temp_ExcludeTrans;
    
    SELECT TransID
		, 	ScoreDiff        
        ,	GROUP_CONCAT(Reason) AS ReasonList
        ,	MAX(MergeGroupID) AS MergeGroupID
	FROM Temp_TransGroup
	GROUP BY TransID, ScoreDiff;

END$$
DELIMITER ;


