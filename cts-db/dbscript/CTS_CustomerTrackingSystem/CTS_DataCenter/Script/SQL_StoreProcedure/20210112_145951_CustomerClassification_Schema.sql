/*
Creator: 20210112@John.Ngo
Task: View Category History [Redmine ID: #145951]
DB: bodb_VR2Model

Reviewer:
*/ 

GO

ALTER TABLE dbo.CustomerClassification
ADD	  LastXDaysMargin			MONEY NULL
	, ProbationPeriodWinloss	MONEY NULL;