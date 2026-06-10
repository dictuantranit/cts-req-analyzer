/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_AssociationGroup`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_AssociationGroup`(
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
            -	20240201@Casey.Huynh: Enhance Performance [Redmine ID: 197706]
            
		Param's Explanation (filtered by):
		
		Example:
        This Function Is Detect Group Association BY input Assocation list table
            DROP TEMPORARY TABLE IF EXISTS Temp_Input;
			CREATE TEMPORARY TABLE Temp_Input(
					FromID 	BIGINT UNSIGNED
				,	ToID	BIGINT UNSIGNED
				,	PRIMARY KEY PK_Temp_Association(FromID,ToID)
			);
		
			CALL CTS_DC_Common_AssociationGroup();

	*/
    DECLARE lv_GroupID BIGINT UNSIGNED;
    DECLARE lv_FromID BIGINT UNSIGNED;
    DECLARE lv_ToID BIGINT UNSIGNED;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE Temp_Association(
			FromID 	BIGINT UNSIGNED
		,	ToID	BIGINT UNSIGNED
        ,	GroupID	INT
        
       ,	PRIMARY KEY PK_Temp_Association(FromID,ToID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
    CREATE TEMPORARY TABLE Temp_Group(
			FromID 	BIGINT UNSIGNED
		,	ToID	BIGINT UNSIGNED
        ,	PRIMARY KEY Temp_Group(FromID,ToID)
	);
    
    INSERT IGNORE INTO Temp_Association(FromID, ToID)
    SELECT	tmp.FromID
		,	tmp.ToID
    FROM Temp_Input AS tmp;
    

    INSERT IGNORE INTO Temp_Association(FromID, ToID)
    SELECT	tmp.ToID
		,	tmp.FromID
    FROM Temp_Input AS tmp;

    SET lv_GroupID = 1;
	lp: LOOP 
		SET lv_FromID = NULL;
        SET lv_ToID = NULL;
        
        SELECT tmp.FromID, tmp.ToID
        INTO lv_FromID, lv_ToID
		FROM Temp_Association AS tmp
        WHERE GroupID IS NULL
		LIMIT 1;
        
        IF lv_FromID IS NULL 
        THEN 
            LEAVE lp; 
        END IF;
        
		INSERT IGNORE INTO Temp_Group(FromID)
		WITH RECURSIVE CTE_Group AS
		(
		  SELECT lv_FromID AS FromID
		  UNION
		  SELECT tmpAs.ToID AS FromID
		  FROM Temp_Association AS tmpAs
		  JOIN CTE_Group ON (CTE_Group.FromID = tmpAs.FromID) 
          WHERE tmpAs.GroupID IS  NULL
		)
        SELECT FromID FROM CTE_Group;
        
        UPDATE Temp_Association AS tmpAs
        INNER JOIN Temp_Group tmpGr ON tmpGr.FromID = tmpAs.FromID
        SET tmpAs.GroupID = lv_GroupID
        WHERE tmpAs.GroupID IS NULL;            
		
        SET lv_GroupID = lv_GroupID + 1;
	END LOOP;

END$$
DELIMITER ;
