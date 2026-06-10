/*<info serverAlias="DBCTS-WASAVerse" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[CTS_SystemParameter_Update]
		@ParamID 		SMALLINT
	,	@ParamValue		VARCHAR(50)
AS
/*
	Created: 20240130@Victoria.Le
	Task : Update System Parameter by ID
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20240130@Victoria.Le:		Initial Writing [Redmine ID: #191955]

	Params Explaination:
		EXECUTE [dbo].[CTS_SystemParameter_Update] 1,1;
*/
BEGIN
	SET NOCOUNT ON;
	
	UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
	SET 	ParameterValue = @ParamValue
	WHERE 	ParameterID = @ParamID;
	
END;