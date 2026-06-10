/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_InsertUserPermission`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_InsertUserPermission`(
        IN ip_UserIDList        JSON
 
    ,   OUT op_ErrorMessage     VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200818@Roger.Le
		Task:		Enhance Associated Account Monitor by NAP Permission 
		DB:			CTS_DataCenter
		Original:
        
        Revision:
			- 20200818@Roger.Le: Created [Redmine ID: #138575]
            - 20200918@Lex.Khuat: Support new probation notification [Redmine ID: #141755]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: #148723]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
                
		Param's Explanation (filtered by):

        Example:
            - CALL CTS_DataCenter.CTS_DC_InsertUserPermission('[{"UserID": 1111, "FuncID": 1}, {"UserID": 1112, "FuncID": 2}], @error)';
	*/

	DECLARE lv_CurrentTime	DATETIME DEFAULT CURRENT_TIME();
    
    # Handle error
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSUserPermission;
    CREATE TEMPORARY TABLE Temp_CTSUserPermission (
			UserID			INT 		UNSIGNED
		,	FuncID			SMALLINT	UNSIGNED
		,	PRIMARY KEY		PK_Temp_CTSUserPermission_UserID(UserID, FuncID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NewCTSUserPermission;
    CREATE TEMPORARY TABLE Temp_NewCTSUserPermission (
			UserID			INT 		UNSIGNED
		,	FuncID			SMALLINT	UNSIGNED
		,	PRIMARY KEY		Temp_NewCTSUserPermission(UserID, FuncID)
    );
    
    #========= GET DATA TO UPDATE =========
	INSERT INTO Temp_CTSUserPermission(UserID, FuncID)
	SELECT 	tmp.UserID
		, 	tmp.FuncID
	FROM JSON_TABLE(ip_UserIDList,
		 "$[*]" COLUMNS(
			  UserID 	INT UNSIGNED		PATH "$.UserID"
			, FuncID	SMALLINT UNSIGNED	PATH "$.FuncID"
		 )) AS tmp;

    
    INSERT INTO Temp_NewCTSUserPermission(UserID, FuncID)
    SELECT DISTINCT t.UserID, t.FuncID
    FROM Temp_CTSUserPermission AS t
		LEFT JOIN CTS_DataCenter.CTSUserPermission AS up ON t.UserID = up.UserID AND t.FuncID = up.FunctionID
	WHERE up.UserID IS NULL 
        OR	(up.UserID IS NOT NULL
			AND NOT EXISTS (SELECT 1 
							FROM CTS_DataCenter.CTSUserPermission AS tup 
                            WHERE tup.UserID = up.UserID 
								AND tup.FunctionID = up.FunctionID
                                AND tup.GrantedTo IS NULL));
    
    #========= REVOKE PERMISSION ON CURRENT USERS =========
    UPDATE CTS_DataCenter.CTSUserPermission AS up
		INNER JOIN CTS_DataCenter.NotificationSettings AS n ON n.UserID = up.UserID AND	n.FunctionID = up.FunctionID
		LEFT JOIN Temp_CTSUserPermission AS temp ON	temp.UserID = up.UserID AND	temp.FuncID = up.FunctionID
	SET		up.LastModifiedDate = lv_CurrentTime
		,	up.GrantedTo =	lv_CurrentTime
        ,	up.IsTurnedOnNotification = 0
        ,	n.LastModifiedDate = lv_CurrentTime
		,	n.GrantedTo =	lv_CurrentTime
	WHERE temp.UserID IS NULL
		AND	up.GrantedTo IS NULL
        AND n.GrantedTo IS NULL;
	
    #========= INSERT NEW PERMISSION LIST =========
    INSERT INTO CTS_DataCenter.CTSUserPermission (UserID, FunctionName, GrantedFrom, GrantedTo, CreatedDate, LastModifiedDate, FunctionID, IsTurnedOnNotification)
    SELECT	DISTINCT temp.UserID
		,	CASE	WHEN temp.FuncID = 1 THEN 'AssociatedAccountMonitor'
					WHEN temp.FuncID = 2 THEN 'ProbationManagement'
                    ELSE 'Unassigned'
			END
		,	lv_CurrentTime AS GrantedFrom
        ,	NULL AS GrantedTo
        ,	lv_CurrentTime AS CreatedDate
        ,	lv_CurrentTime AS LastModifiedDate
        ,	temp.FuncID
        ,	1
    FROM Temp_CTSUserPermission AS temp
    LEFT JOIN CTS_DataCenter.CTSUserPermission AS up
		ON	temp.UserID = up.UserID
        AND	temp.FuncID = up.FunctionID
	WHERE up.UserID IS NULL
		OR	(up.UserID IS NOT NULL
			AND NOT EXISTS (SELECT 1 
							FROM CTS_DataCenter.CTSUserPermission AS tup 
                            WHERE tup.UserID = up.UserID 
								AND tup.FunctionID = up.FunctionID
                                AND tup.GrantedTo IS NULL));
                                
	INSERT INTO CTS_DataCenter.NotificationSettings (UserID, FunctionID, FunctionName, GrantedFrom, GrantedTo, CreatedDate, LastModifiedDate)
    SELECT	DISTINCT temp.UserID
        ,	temp.FuncID
		,	CASE	WHEN temp.FuncID = 1 THEN 'AssociatedAccountMonitor'
					WHEN temp.FuncID = 2 THEN 'ProbationManagement'
                    ELSE 'Unassigned'
			END
		,	lv_CurrentTime AS GrantedFrom
        ,	NULL AS GrantedTo
        ,	lv_CurrentTime AS CreatedDate
        ,	lv_CurrentTime AS LastModifiedDate
    FROM Temp_NewCTSUserPermission AS temp;
    
END$$

DELIMITER ;

