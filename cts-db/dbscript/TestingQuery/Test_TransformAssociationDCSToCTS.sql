UPDATE DCS_DataCenter.Association
SET IsCTSTransformed = 0
WHERE AssociationID < 100;


SELECT *
FROM DCS_DataCenter.Association
WHERE AssociationID < 100;

	SELECT	CONCAT(', {"AssociationId":', tas.AssociationID
			, ', "AccountId":', tas.AccountID
            , ', "DeviceId":', tas.DeviceID
            , ', "CreatedTime": "', tas.CreatedTime, '"'
            , ', "SubscriberId":', tas.SubscriberID,'}')
	FROM Temp_Association AS tas;   
    

CALL DCS_DataCenter.DCS_DC_TransformToCTS_Association_GetPackage(10,2);

CALL DCS_DataCenter.DCS_DC_TransformToCTS_Association_Unsuccess_GetPackage(10,2);


CALL CTS_DataCenter.CTS_DC_TransformAssociationByDevice
('[
    {"AssociationId":55, "AccountId":55, "DeviceId":54, "CreatedTime": "2019-06-13 03:13:29.0000", "SubscriberId":6}
, {"AssociationId":54, "AccountId":54, "DeviceId":53, "CreatedTime": "2019-06-13 03:13:29.0000", "SubscriberId":6}
, {"AssociationId":53, "AccountId":53, "DeviceId":52, "CreatedTime": "2019-06-13 03:13:29.0000", "SubscriberId":6}
, {"AssociationId":52, "AccountId":52, "DeviceId":51, "CreatedTime": "2019-06-13 03:13:29.0000", "SubscriberId":6}
, {"AssociationId":51, "AccountId":51, "DeviceId":50, "CreatedTime": "2019-06-13 03:13:29.0000", "SubscriberId":6}
, {"AssociationId":50, "AccountId":50, "DeviceId":5, "CreatedTime": "2019-06-13 03:13:28.0000", "SubscriberId":6}
, {"AssociationId":49, "AccountId":49, "DeviceId":49, "CreatedTime": "2019-06-13 03:13:28.0000", "SubscriberId":6}
, {"AssociationId":48, "AccountId":48, "DeviceId":48, "CreatedTime": "2019-06-13 03:13:28.0000", "SubscriberId":6}
, {"AssociationId":47, "AccountId":47, "DeviceId":47, "CreatedTime": "2019-06-13 03:13:28.0000", "SubscriberId":6}
, {"AssociationId":46, "AccountId":46, "DeviceId":46, "CreatedTime": "2019-06-13 03:13:28.0000", "SubscriberId":6}
, {"AssociationId":35, "AccountId":35, "DeviceId":35, "CreatedTime": "2019-06-13 03:13:24.0000", "SubscriberId":6}
, {"AssociationId":34, "AccountId":34, "DeviceId":34, "CreatedTime": "2019-06-13 03:13:24.0000", "SubscriberId":6}
, {"AssociationId":33, "AccountId":33, "DeviceId":33, "CreatedTime": "2019-06-13 03:13:23.0000", "SubscriberId":6}
, {"AssociationId":32, "AccountId":32, "DeviceId":32, "CreatedTime": "2019-06-13 03:13:22.0000", "SubscriberId":6}
, {"AssociationId":31, "AccountId":31, "DeviceId":31, "CreatedTime": "2019-06-13 03:13:22.0000", "SubscriberId":6}
, {"AssociationId":30, "AccountId":30, "DeviceId":30, "CreatedTime": "2019-06-13 03:13:21.0000", "SubscriberId":6}
, {"AssociationId":29, "AccountId":29, "DeviceId":29, "CreatedTime": "2019-06-13 03:13:21.0000", "SubscriberId":6}
, {"AssociationId":28, "AccountId":28, "DeviceId":28, "CreatedTime": "2019-06-13 03:13:20.0000", "SubscriberId":6}
, {"AssociationId":27, "AccountId":27, "DeviceId":27, "CreatedTime": "2019-06-13 03:13:19.0000", "SubscriberId":6}
, {"AssociationId":26, "AccountId":26, "DeviceId":26, "CreatedTime": "2019-06-13 03:13:19.0000", "SubscriberId":6}
]');