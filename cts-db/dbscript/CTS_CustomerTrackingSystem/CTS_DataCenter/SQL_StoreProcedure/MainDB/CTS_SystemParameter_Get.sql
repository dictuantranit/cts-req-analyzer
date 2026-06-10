/*<info serverAlias="DBCTS-WASAVerse" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[CTS_SystemParameter_Get]
		@ParamID 		SMALLINT
AS
/*
	Created: 20240130@Victoria.Le
	Task : Get System Parameter by ID
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20240130@Victoria.Le:		Initial Writing [Redmine ID: #191955]

	Params Explaination:
		EXECUTE [dbo].[CTS_SystemParameter_Get] 1;
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT 	s.ParameterValue
		,	s.ParameterDataType
    FROM 	dbo.SystemParameter AS s WITH (NOLOCK)
    WHERE 	s.ParameterID = @ParamID;
	
END;
