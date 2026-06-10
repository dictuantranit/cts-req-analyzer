/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_MBTransaction_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_MBTransaction_GetPackage`(
		IN ip_LimitTotalRecord 	INT
	,   IN ip_NoOfBatch 		INT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20241205@Jonathan.Doan
		Task : Transform Transaction
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20241205@Jonathan.Doan: Integrate Mobile App (Phase 2) [Redmine ID: #213401]
			- 20250811@Jonathan.Doan: Update new rule [Redmine ID: #235457]

		Param's Explanation (filtered by):
			CALL DCS_DC_Transform_MBTransaction_GetPackage(1, 30);
	*/
	DECLARE lv_NoOfBatch 	INT;
	DECLARE lv_RowId 		INT DEFAULT 0;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_MBTransaction;
	DROP TEMPORARY TABLE IF EXISTS Temp_CheckSameDevice;
	DROP TEMPORARY TABLE IF EXISTS Temp_SetBatchID;

	CREATE TEMPORARY TABLE Temp_MBTransaction(
			ID								BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	MBRawTransactionID				BIGINT UNSIGNED
		,	SameDeviceID					BIGINT UNSIGNED DEFAULT 0
		,	RecoverType						SMALLINT 		DEFAULT 0
		,	MBDeviceCodeTaggingID			BIGINT UNSIGNED
		,	MBDeviceCodeMachineAccountID	BIGINT UNSIGNED
		,	MBDeviceCodeMachineMediaID		BIGINT UNSIGNED
		,   BatchID							INT
	);

	CREATE TEMPORARY TABLE Temp_CheckSameDevice(
			ID								BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	SameDeviceID					BIGINT UNSIGNED DEFAULT 0
		,	RecoverType						SMALLINT 		DEFAULT 0
		,	FirstDeviceID					BIGINT UNSIGNED
		,	SecondDeviceID					BIGINT UNSIGNED
		,	ThirdDeviceID					BIGINT UNSIGNED
	);

	CREATE TEMPORARY TABLE Temp_SetBatchID(
			SameDeviceID					BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	BatchID							INT 			DEFAULT 0
	);
	
	/********************** Check Same Device ***********************************/
	INSERT INTO Temp_MBTransaction(ID, MBRawTransactionID, MBDeviceCodeTaggingID, MBDeviceCodeMachineAccountID, MBDeviceCodeMachineMediaID)
	SELECT 	ID
		,	MBRawTransactionID
		,	IFNULL(MBDeviceCodeTaggingID, 0)		AS MBDeviceCodeTaggingID
		,	IFNULL(MBDeviceCodeMachineAccountID, 0)	AS MBDeviceCodeMachineAccountID
		,	IFNULL(MBDeviceCodeMachineMediaID, 0)	AS MBDeviceCodeMachineMediaID
	FROM DCS_DataCenter.MBTransaction
	ORDER BY ID ASC
	LIMIT ip_LimitTotalRecord;
	
	INSERT INTO Temp_CheckSameDevice(ID, FirstDeviceID, SecondDeviceID, ThirdDeviceID)
	SELECT 	MBRawTransactionID AS ID
		,   MBDeviceCodeTaggingID			AS ThirdDeviceID
		,   MBDeviceCodeMachineAccountID	AS FirstDeviceID
		,   MBDeviceCodeMachineMediaID		AS SecondDeviceID
	FROM Temp_MBTransaction;
	
	CALL DCS_DataCenter.DCS_DC_Transform_MBDeviceMapping_UpdateTheSameDevice('Temp_CheckSameDevice');
	
	/********************** Set BatchID ***********************************/
	INSERT INTO Temp_SetBatchID(SameDeviceID)
	SELECT DISTINCT SameDeviceID
	FROM Temp_CheckSameDevice;
	
	SELECT COUNT(SameDeviceID)
	INTO @CountFirstDevice
	FROM Temp_SetBatchID;
	
	SET @RowId = 0;
	SET lv_NoOfBatch = CEIL(@CountFirstDevice / ip_NoOfBatch);
	
	UPDATE Temp_SetBatchID
	SET BatchID = CEIL(@RowId := @RowId + 1 / lv_NoOfBatch)
	ORDER BY (SameDeviceID = 0) ASC, SameDeviceID ASC;
	
	UPDATE Temp_MBTransaction AS tmp
		INNER JOIN Temp_CheckSameDevice AS tmpSD ON tmpSD.ID = tmp.MBRawTransactionID
		INNER JOIN Temp_SetBatchID AS tmpB ON tmpB.SameDeviceID = tmpSD.SameDeviceID
	SET tmp.BatchID = tmpB.BatchID,
		tmp.SameDeviceID = tmpSD.SameDeviceID,
		tmp.RecoverType = tmpSD.RecoverType;
	
	/********************** RETURN OUTPUT ***********************************/
	SELECT	tmp.ID AS TransID
		,	tmp.MBRawTransactionID
		,	tmp.MBDeviceCodeMachineAccountID
		,	tmp.MBDeviceCodeMachineMediaID
		,	tmp.MBDeviceCodeTaggingID
		,	tmpSD.SameDeviceID
		,	tmpSD.RecoverType
		,	tmpB.BatchID
	FROM Temp_MBTransaction AS tmp
		INNER JOIN Temp_CheckSameDevice AS tmpSD ON tmpSD.ID = tmp.MBRawTransactionID
		INNER JOIN Temp_SetBatchID AS tmpB ON tmpB.SameDeviceID = tmpSD.SameDeviceID;

END$$
DELIMITER ;