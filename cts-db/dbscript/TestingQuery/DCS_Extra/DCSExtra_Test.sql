USE DCS_Extra;

#========INSERT RAW TRANSACTION===============================================

TRUNCATE TABLE DCS_Extra.AccountLastLoginTimeProcess;
TRUNCATE TABLE DCS_Extra.ActionResult;
TRUNCATE TABLE DCS_Extra.Association;
TRUNCATE TABLE DCS_Extra.Device;
TRUNCATE TABLE DCS_Extra.DeviceCode;
TRUNCATE TABLE DCS_Extra.DeviceFingerprint;
TRUNCATE TABLE DCS_Extra.DeviceType;
TRUNCATE TABLE DCS_Extra.OS;
TRUNCATE TABLE DCS_Extra.ProcessedTransaction;
TRUNCATE TABLE DCS_Extra.Transaction;
TRUNCATE TABLE DCS_Extra.Transaction07;
TRUNCATE TABLE DCS_Extra.URL;
TRUNCATE TABLE DCS_Extra.UserAgent;
TRUNCATE TABLE DCS_Extra.BotComponent;

#===============Generate for RawTransaction===============================================================
TRUNCATE TABLE RawTransaction;
CALL DCS_ET_Transform_RawTrans_Insert (@ip_RawTransJson:='[
		{"LoginName":"DenVau","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv10016ce7074622bc18a921f8be1e60","FingerprintCode":"ade5b939c13195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0", "Action":"login","ActionResult":"login -> successfully","InvalidDevice":null,"IP":"14.167.17.120","IPId":245830008,"PluginID":null,"TransTime":"2023-06-29 00:00:00.0201","URL":"http://m122.viva88.net:806/FpsHandler","UserAgent":"Mozilla/5.0 (iPhone; CPU iPhone OS 15_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Mobile/15E148 Safari/604.1","FlaggedCode":"headless_chrome", "BotDetection":"detectAppVersion,detectUserAgent"}
	,	{"LoginName":"PhamHoaiNam","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"NguyenHa","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"VuCatTuong","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"PhanManhQuynh","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1002ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"BuiAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"VickyNhung","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"HaAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	, 	{"LoginName":"HuongTram","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1008ace7074622bc18a921f8be1e60","FingerprintCode":"df008af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"NguyenThao","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"MyTam","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"MAXBET789Y","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"dv1001df00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"DenVau","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1002ace7074622bc18a921f8be1e60","FingerprintCode":"dv1001df00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"PhamHoaiNam","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1002ace7074622bc18a921f8be1e60","FingerprintCode":"dv1003df00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"NguyenHa","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1003ace7074622bc18a921f8be1e60","FingerprintCode":"dv1003df00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"VuCatTuong","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1003ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"PhanManhQuynh","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1005ace7074622bc18a921f8be1e60","FingerprintCode":"df005af00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"BuiAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1006ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00695aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"BuiAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1006ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00695aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"BuiAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1007ace7074622bc18a921f8be1e60","FingerprintCode":"df001af00695aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"VickyNhung","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"CTMAX","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df007af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	, 	{"LoginName":"HaAnhTuan","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1008ace7074622bc18a921f8be1e60","FingerprintCode":"df008af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"HuongTram","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"df009af00195aaae06466b6757754413fcdc2a;df002a3edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	,	{"LoginName":"NguyenThao","TransTime":"2023-06-29 00:00:00.0201","SubscriberName":"Velki","DeviceCode":"dv1001ace7074622bc18a921f8be1e60","FingerprintCode":"dv1010df00195aaae06466b6757754413fcdc2a;0423c13edf617398aed953a6fd4e7d24","TransStatus":"0","Action":"login","ActionResult":"login -> successfully","DeviceCode":"a707e6620cce48a4ada3cd3887e5d77f","FingerprintCode":"f4cf2f4634bfd83191d70c4f1913cc79878cce5f;4c7acb513373c49e797f2f35c6e1f99d","InvalidDevice":null,"IP":"103.199.41.17","IPId":1741105425,"PluginID":null,"TransTime":"2023-06-29 00:00:01.0201","URL":"http://l9j7ma.cx5888.com/FpsHandler","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","FlaggedCode":"unknown", "BotDetection":""}
	
]');

BEGIN;
DROP  temporary table  If exists Temp_DataUserAgent;
Create temporary table Temp_DataUserAgent(ID INT auto_increment Primary Key, UserAgent VARCHAR(10000));
Insert into Temp_DataUserAgent (UserAgent)
VALUES('Mozilla/5.0 (Linux; Android 10; CPH2185 Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36 MMWEBID/6297 MicroMessenger/7.0.21.1783(0x27001543) Process/tools WeChat/arm64 Weixin GPVersio...')
,('Mozilla/5.0 (Linux; Android 8.1.0; CPH1901 Build/OPM1.171019.026; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/114.0.5735.60 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/418.0.0.33.69;]')
,('Mozilla/5.0 (Linux; Android 10; SKR-A0 Build/G66X2106040CN00MQ5; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/81.0.4044.138 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/6f7q6xsMVrRu6P436ESVeg==')
,('Mozilla/5.0 (Linux; Android 8.0.0; ATU-AL10 Build/HUAWEIATU-AL10; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/70.0.3538.110 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/JXRsxsCw223QtkpJs5nBsw==')
,('Mozilla/5.0 (Linux; Android 12; ANA-AN00 Build/HUAWEIANA-AN00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/92.0.4515.105 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/1hm1olYzP5tEhJeaglBKKQ==')
,('Mozilla/5.0 (Linux; Android 7.1.1; CPH1725) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.50 Mobile Safari/537.36')
,('Mozilla/5.0 (Linux; Android 13; V2172A Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/101.0.4951.74 Mobile Safari/537.36 APKPacker/1.9.0')
,('Mozilla/5.0 (Linux; Android 10; V2057A Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/EYCsxbG16qywJyYaODTCVNextM/sUtIWdr4QM+XxFrs=')
,('Mozilla/5.0 (Linux; Android 10; AQM-AL00 Build/HUAWEIAQM-AL00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/88.0.4324.93 Mobile Safari/537.36 game_portal/3 game_platform/3 HTTP_BB_FORWARDED/DDoItQ9/CMMIyf7O0yI0Yw==')
,('Mozilla/5.0 (Linux; Android 11; V2158A Build/RP1A.200720.012; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/9IEwuk7Nx3Jr5RWfApGz64s0dOfPN1jv0QKu2xv5kUw=')
,('Mozilla/5.0 (Linux; Android 10; TNY-AL00 Build/HUAWEITNY-AL00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/wWDUBMs4oR1v9e2fv0SObw==')
,('Mozilla/5.0 (Linux; Android 11; TFY-AN40 Build/HONORTFY-AN40; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36jp_runtime/embeddedjp_runtime/embeddedjp_runtime/embedded')
,('Mozilla/5.0 (Linux; Android 8.1.0; SM-G610F Build/M1AJQ; in-id) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.136 Mobile Safari/537.36 Puffin/9.2.1.50809AP')
,('Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 TSAPP/iPhoneOS12.2')
,('Mozilla/5.0 (Linux; Android 8.1.0; SM-C710F Build/M1AJQ; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/96.0.4664.45 Mobile Safari/537.36 Line/12.3.1/IAB')
,('Mozilla/5.0 (Linux; Android 10; V2024A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.84 Mobile Safari/537.36 VivoBrowser/9.0.10.0')
,('Mozilla/5.0 (Linux; Android 12; LIO-AL00 Build/HUAWEILIO-AL00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/92.0.4515.105 Mobile Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/xspsAjh1vPoIgiFlXd5wkQVJojWbsoSnff0bMxizhqQ=')
,('Mozilla/5.0 (Linux; Android 10; ART-L28) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.83 Mobile Safari/537.36')
,('Mozilla/5.0 (Linux; Android 10; JEF-AN00 Build/HUAWEIJEF-AN00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/78.0.3904.108 Mobile Safari/537.36HL8 MOBILE')
,('Mozilla/5.0 (Linux; U; Android 6.0; zh-CN; Redmi Note 4 Build/MRA58K) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/78.0.3904.108 UCBrowser/13.8.8.1169 Mobile Safari/537.36')
,('Mozilla/5.0 (Linux; Android 9; SM-T395 Build/PPR1.180610.011; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/89.0.4389.86 Safari/537.36 Line/11.3.1/IAB')
,('Mozilla/5.0 (Linux; Android 8.1.0; SM-T585 Build/M1AJQ; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/77.0.3865.92 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 8.1.0; SM-P585Y) AppleWebKit/537.36 (KHTML, like Gecko) coc_coc_browser/89.1.206 Chrome/83.1.4103.206 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 8.0.0; SM-T825Y) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 5.1.1; SM-T285 Build/LMY47V; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/90.0.4430.82 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 5.1.1; HUAWEI M2-A01L) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.101 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 4.4.2; SM-T900 Build/KOT49H) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.59 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 13; SM-T225 Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.5672.76 Safari/537.36 OPX/2.0')
,('Mozilla/5.0 (Linux; Android 12; SM-F926N Build/SP2A.220305.013; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/99.0.4844.88 Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/nVlDhySgUGLb9YALH2kUmg==')
,('Mozilla/5.0 (Linux; Android 11; M2011J18C Build/RKQ1.201112.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/92.0.4515.131 Safari/537.36 mailapp/6.3.5')
,('Mozilla/5.0 (Linux; Android 11; M2007J20CI Build/RKQ1.200826.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/111.0.5563.58 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 11; BRT-AN09 Build/HONORBRT-AN09; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/88.0.4324.93 Safari/537.36 game_portal/4 game_platform/3 HTTP_BB_FORWARDED/3hjLovo+nM7K6xGrYuOdVg==')
,('Mozilla/5.0 (Linux; Android 10; SM-T865) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.86 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 10; SM-T505) AppleWebKit/537.36 (KHTML, like Gecko) coc_coc_browser/93.0.188 Chrome/87.0.4280.188 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 10; Redmi 8A Build/QKQ1.191014.001; xx-xx) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/109.0.5414.117 Safari/537.36/Xiaomi AppShellVer:2.4.22 UUID/f638fd93-31b4-352a-9f2f-24921ff61981')
,('Mozilla/5.0 (Linux; Android 10; Lenovo TB-X306X Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/104.0.5112.69 Safari/537.36-android-cordova')
,('Mozilla/5.0 (Linux; Android 10; Lenovo TB-8705X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.74 Safari/537.36')
,('Mozilla/5.0 (Linux; Android 10; KRJ-AN00 Build/HUAWEIKRJ-AN00; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/97.0.4692.98 Safari/537.36 T7/13.21 BDOS/1.0 (HarmonyOS 2.2.0) SP-engine/2.59.0 baiduboxapp/13.21.0.11 (Baidu; P1 10) NABar/1.0')
,('Mozilla/5.0 (iPad; CPU OS 7_0 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A465 Safari/9537.53 winner/1603829984')
,('Dalvik/2.1.0 (Linux; U; Android 6.0.1; SM-J700H Build/MMB29K) VersionName/1.0.241')
,('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36/FCD87CE2D751453')
,('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36/663CE73113E')
,('Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) QtWebEngine/5.15.0 Chrome/80.0.3987.163 Safari/537.36')
,('Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.106 Safari/FBB7F4')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.102 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 11_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5074.124 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.129 Safari/537.36 OPR/68.0.3618.91')
,('Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/106.0.5174.153 Chrome/106.0.5174.153 Safari/537.36')
,('{referrer=utm_source=apps.facebook.com&utm_campaign=fb4a&utm_content=%7B%22app%22%3A101067539629116%2C%22t%22%3A1683342641%2C%22source%22%3A%7B%22data%22%3A%2236211cc8121936f8cd9bcbcbb34d4cc62aab7e8918e307f2fd1c8dfd11355d8de5cdc4ee284e20dde41f8aee0c17a2e07678fb0006aa14feb791a431c72f636b177366e966dd9656a4e798c55365ef4dce0459e8eef18d09b62d9f19c672ed5e42e06d68d4029c833427e70ad67c03d30dd1a1d3a777ecb0701d465978ebf1f0dcd472b7e93199dc1e0b187eb10de4e43eb2b8d79c41d4b7efed2eb84d12c762fd6a8dd3fb77f54c7c17876bc273087ea7c49be62c2b3828b6b6be7cb6c1b438d56bb4e2a63db709d138d93f44bad90f94be448c7db3fb26eb30175f9e85b6cc0536f854d175c4ae438a69e97bc9140dc00e4dfe347c25b3f275e2ffc39734fa47129f3519d4199363f7ac20625dce45474ad0cc232656e0a46b1150a6acc5c636cc5b1b8ca2ceff21106f803a6b19d07a643bbd599192760780ca5e57aef154f948b93e064691300fd9ce79de2c4224c4c3ae7f9ae7a06d54271bbcc0d42c17dc4762848110065ce241d2878dda0e1b57eab2fa82bb482804aecf6205f2754e15a514d813b54a0b347c818027260aeb2d29e2a8f35ad95c691d0e43e59cb2debc%22%2C%')
,('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4682.74 Safari/537.36')
,('Mozilla/5.0 (Windows NT 6.3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.71 Safari/537.36')
,('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/4244.27.29.65 Safari/1580.434')
,('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.167 Safari/537.36')
,('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.129 chimlac/80.0.3987.129 Safari/537.36')
,('Mozilla/5.0 (Windows NT 7.116; WOW64) Chrome/90.17.78.0216769.13-019903EE145;1399.0336 Smiooth 248.03,9963.991023')
,('Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4459.2 Safari/537.36')
,('Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36 Edg/111.0.1661.51')
,('Mozilla/5.0 (Windows NT 5.1; rv:52.9) Gecko/20100101 Goanna/3.4 Firefox/52.9 PaleMoon/27.9.7')
,('Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.149 Safari/91659F')
,('Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.1912.46 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Whale/2.8.6.3883 Safari/605.1.15')
,('Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_8; en-us) AppleWebKit/533.21.1 (KHTML, like Gecko) iCab/4.8 Safari/533.16')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 13_1) AppleWebKit/605.1.15 (KHTML, like Gecko) coc_coc_browser/83.0.156 CriOS/77.0.3865.156 Safari/605.1')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/98.0.4758.368 Version/11.1.1 Safari/605.1.15')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/608.1.49 (KHTML, like Gecko) Version/13.0 Safari/608.1.49 Maxthon/5.1.60')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) coc_coc_browser/95.0.214 CriOS/89.0.4389.214 Version/11.1.1 Safari/605.1.15')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/611.2.7 (KHTML, like Gecko) Version/14.1.1 Safari/611.2.7 Maxthon/5.1.60')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 YaBrowser/21.11.5.594.10 SA/3 Safari/605.1.15')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/606.1.36 (KHTML, like Gecko) QHBrowser/317 QihooBrowser/4.0.10')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/95.0.4638.54 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Safari/605.1.15 Maxthon/6.0.8.185')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) coc_coc_browser/83.0.214 CriOS/77.0.3865.214 Safari/605.1')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/72.0.3617.0 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/108.0.5359.496 Version/11.1.1 Safari/605.1.15')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_5) AppleWebKit/609.2.9 (KHTML, like Gecko) Version/13.1.1 Safari/609.2.9 Maxthon/5.1.60')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/108.0.5351.0 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/92.0.4515.107 Safari/537.36')
,('/1 CFNetwork/811.5.4 Darwin/16.6.0')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/92.0.4515.159 Safari/537.36')
,('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_5) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/110.0.5481.556 Version/11.1.1 Safari/605.1.15')
,('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.2; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729) SogouMSE,SogouMobileBrowser/6.3.7')
,('Mozilla/5.0 (Linux; Android 7.0;) AppleWebKit/537.36 (KHTML, like Gecko) Mobile Safari/537.36 (compatible; AspiegelBot)')
,('Mozilla/5.0 (compatible;Impact Radius Compliance Bot) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.92 Safari/537.36')
,('Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.268')
,('Mozilla/5.0 (en-us) AppleWebKit/525.13 (KHTML, like Gecko; Google Web Preview) Version/3.1 Safari/525.13')
,('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) BetBot/2.0.2 Chrome/80.0.3987.158 Electron/8.2.0 Safari/537.36')
,('{referrer=adjust_external_click_id=E.C.P.CsoBsxlQb230UlZTHV8A0VqpGyO8LnCmRNYvUkrS-0TD-TyqHKaU2me1XGb0VT_i8N-zCtjsxDrUKmrMPZ3s5-tAhm6jFOiV0BcAb5yyBXCioIl_Gt3xl_Du5iwC9ezzaoYi-E_FcJlgJwSm0CCJfEybTdJjTWSn9motXr20d090d4TdWQEDp4uSyD6SwAgD4RSZbm6EsjykU0mIR7V6k...')
,('Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.2; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729) SogouMSE,SogouMobileBrowser/6.0.16')
,('facebookexternalhit/1.1')
,('WhatsApp/2.2031.4 N')
,('Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) crawl365/0.1.0 Chrome/83.0.4103.100 Electron/9.0.3 Safari/537.36')
,('Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.96 Ver/zaoganma1.zaoganma1 Safari/537.36')
,('WebZIP/3.5 (http://www.spidersoft.com)')
,('everyfeed-spider/2.0 (http://www.everyfeed.com)')
,('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.5005.115 Safari/537.36 PTST/220609.133020')
,('Mozilla/5.0 (X11; Linux x86_64; CYBORG001 Build/PI; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/110.0.5481.153 Safari/537.36')
,('facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)')
,('SAMSUNG-SGH-E250/1.0 Profile/MIDP-2.0 Configuration/CLDC-1.1 UP.Browser/6.2.3.3.c.1.101 (GUI) MMP/2.0 (compatible; Googlebot-Mobile/2.1; http://www.google.com/bot.html)')
,('Googlebot-News')
,('DoCoMo/2.0 N905i(c100;TB;W24H16) (compatible; Googlebot-Mobile/2.1; http://www.google.com/bot.html)')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K GB ATV3 Build/PTT1.190515.001.S52) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.250')
,('Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/2.2rab Chrome/76.0.3809.146/6.0 TV Safari/537.36')
,('Mozilla/5.0 (PlayStation; PlayStation 4/9.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15')
,('Mozilla/5.0 (Linux; Andr0id 8.0.0; BRAVIA 2015 Build/OPR2.170623.027.S16) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.232 Model/Sony-BRAVIA-2015')
,('Mozilla/5.0 (PlayStation 4 7.00) AppleWebKit/605.1.15 (KHTML, like Gecko)')
,('Mozilla/5.0 (PlayStation 4 7.01) AppleWebKit/605.1.15 (KHTML, like Gecko)')
,('Mozilla/5.0 (PlayStation; PlayStation 4/10.01) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15')
,('Mozilla/5.0 (PlayStation; PlayStation 4/8.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA VH1 Build/PTT1.190515.001.S52) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.242 Model/Sony-BRAVIA-VH1')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K GB ATV3 Build/PTT1.190515.001.S43) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.250 Model/Sony-BRAVIA-4K-GB-ATV3')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K UR3 Build/PTT1.190515.001.S104) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.250 Model/Sony-BRAVIA-4K-UR3')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 2K GB ATV3 Build/PTT1.190515.001.S43) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.250 Model/Sony-BRAVIA-2K-GB-ATV3')
,('Mozilla/5.0 (PlayStation 4 6.72) AppleWebKit/605.1.15 (KHTML, like Gecko)')
,('Mozilla/5.0 (SMART-TV; Linux; Tizen 4.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/2.1 Chrome/56.0.2924.0 TV Safari/537.36')
,('Mozilla/5.0 (PlayStation; PlayStation 4/8.03) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K GB ATV3 Build/PTT1.190515.001.S52) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.250 Model/Sony-BRAVIA-4K-GB-ATV3')
,('Mozilla/5.0 (PlayStation; PlayStation 4/9.04) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K UR1 Build/PTT1.190515.001.S65) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.161 Model/Sony-BRAVIA-4K-UR1')
,('Mozilla/5.0 (SMART-TV; Linux; Tizen 7.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/6.0 Chrome/94.0.4606.31 TV Safari/537.36')
,('Mozilla/5.0 (Linux; Andr0id 9; BRAVIA 4K UR2 Build/PTT1.190515.001.S65) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36 OPR/46.0.2207.0 OMI/4.13.5.431.DIA5HBBTV.161 Model/Sony-BRAVIA-4K-UR2');
END;
SELECT MIN(ID), Max(ID) FROM Temp_DataUserAgent;

SELECT COUNT(1) FROM RawTransaction_bk;

SET @TransID = 0;
UPDATE RawTransaction_bk
SET LoginName = CONCAT(ELT(0.5 + RAND()*47,'Affecting','Exciting','Heated','Hysterical','Impassioned','Moving','Nervous','Passionate','Poignant','Sensitive','Sentimental','Spontaneous','Touching','Ardent','Disturbed','Ecstatic','Emotive','Enthusiastic','Excitable','Falling Apart','Fanatical','Feeling','Fervent','Fervid','Fickle','Fiery','Heartwarming','Histrionic','Histrionical','Hot-Blooded','Impetuous','Impulsive','Irrational','Overwrought','Pathetic','Responsive','Roused','Sentient','Stirred','Stirring','Susceptible','Tear-Jerking','Temperamental','Tender','Thrilling','Warm','Zealous')
			,ELT(0.5 + RAND()*8,'1','2','3','4','5','6','7','8'))
	, SubscriberName = ELT(0.5 + RAND()*20,'Velki','CTMAX','Velki','CTMAX','Velki','NoName','CTMAX','Velki','CTMAX','Velki','CTMAX','Velki','CTMAX','Velki','CTMAX','Velki','CTMAX','Velki','CTMAX','Velki','CTMAX')
    , TransTime = timestampadd(MICROSECOND, 502344*TransID,NOW())
    , TransStatus = 0, IsProcessed = 0
    , URL = CONCAT("http://",SubscriberName,ELT(0.5 + RAND()*3,'extra1','extra2','extra3'),".com")
    , IP = CONCAT(ELT(0.5 + RAND()*38,'101.46.224.','102.128.165.','102.129.156.','102.164.247.','102.165.1.','102.165.5.','102.165.50.','102.165.52.','102.165.8.','102.177.114.','102.217.68.','102.223.79.','102.69.149.','103.104.170.','103.112.0.','103.112.3.','103.114.162.','103.122.179.','103.143.76.','101.46.227.255','102.128.165.255','102.129.156.255','102.164.247.255','102.165.1.255','102.165.5.255','102.165.50.255','102.165.55.255','102.165.9.255','102.177.114.255','102.217.68.255','102.223.79.255','102.69.149.255','103.104.170.255','103.112.0.255','103.112.3.255','103.114.162.255','103.122.179.255','103.143.76.255')
				,ELT(0.5 + RAND()*215,'1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','43','44','45','46','47','48','49','50','51','52','53','54','55','56','57','58','59','60','61','62','63','64','65','66','67','68','69','70','71','72','73','74','75','76','77','78','79','80','81','82','83','84','85','86','87','88','89','90','91','92','93','94','95','96','97','98','99','100','101','102','103','104','105','106','107','108','109','110','111','112','113','114','115','116','117','118','119','120','121','122','123','124','125','126','127','128','129','130','131','132','133','134','135','136','137','138','139','140','141','142','143','144','145','146','147','148','149','150','151','152','153','154','155','156','157','158','159','160','161','162','163','164','165','166','167','168','169','170','171','172','173','174','175','176','177','178','179','180','181','182','183','184','185','186','187','188','189','190','191','192','193','194','195','196','197','198','199','200','201','202','203','204','205','206','207','208','209','210','211','212','213','214','215'))
	, DeviceCode = ELT(0.5 + RAND()*99,'dc101ace7074622bc18a921f8bea101','dc102ace7074622bc18a921f8bea102','dc103ace7074622bc18a921f8bea103','dc104ace7074622bc18a921f8bea104','dc105ace7074622bc18a921f8bea105','dc106ace7074622bc18a921f8bea106','dc107ace7074622bc18a921f8bea107','dc108ace7074622bc18a921f8bea108','dc109ace7074622bc18a921f8bea109','dc110ace7074622bc18a921f8bea110','dc111ace7074622bc18a921f8bea111','dc112ace7074622bc18a921f8bea112','dc113ace7074622bc18a921f8bea113','dc114ace7074622bc18a921f8bea114','dc115ace7074622bc18a921f8bea115','dc116ace7074622bc18a921f8bea116','dc117ace7074622bc18a921f8bea117','dc118ace7074622bc18a921f8bea118','dc119ace7074622bc18a921f8bea119','dc120ace7074622bc18a921f8bea120','dc121ace7074622bc18a921f8bea121','dc122ace7074622bc18a921f8bea122','dc123ace7074622bc18a921f8bea123','dc124ace7074622bc18a921f8bea124','dc125ace7074622bc18a921f8bea125','dc126ace7074622bc18a921f8bea126','dc127ace7074622bc18a921f8bea127','dc128ace7074622bc18a921f8bea128','dc129ace7074622bc18a921f8bea129','dc130ace7074622bc18a921f8bea130','dc131ace7074622bc18a921f8bea131','dc132ace7074622bc18a921f8bea132','dc133ace7074622bc18a921f8bea133','dc134ace7074622bc18a921f8bea134','dc135ace7074622bc18a921f8bea135','dc136ace7074622bc18a921f8bea136','dc137ace7074622bc18a921f8bea137','dc138ace7074622bc18a921f8bea138','dc139ace7074622bc18a921f8bea139','dc140ace7074622bc18a921f8bea140','dc141ace7074622bc18a921f8bea141','dc142ace7074622bc18a921f8bea142','dc143ace7074622bc18a921f8bea143','dc144ace7074622bc18a921f8bea144','dc145ace7074622bc18a921f8bea145','dc146ace7074622bc18a921f8bea146','dc147ace7074622bc18a921f8bea147','dc148ace7074622bc18a921f8bea148','dc149ace7074622bc18a921f8bea149','dc150ace7074622bc18a921f8bea150','dc151ace7074622bc18a921f8bea151','dc152ace7074622bc18a921f8bea152','dc153ace7074622bc18a921f8bea153','dc154ace7074622bc18a921f8bea154','dc155ace7074622bc18a921f8bea155','dc156ace7074622bc18a921f8bea156','dc157ace7074622bc18a921f8bea157','dc158ace7074622bc18a921f8bea158','dc159ace7074622bc18a921f8bea159','dc160ace7074622bc18a921f8bea160','dc161ace7074622bc18a921f8bea161','dc162ace7074622bc18a921f8bea162','dc163ace7074622bc18a921f8bea163','dc164ace7074622bc18a921f8bea164','dc165ace7074622bc18a921f8bea165','dc166ace7074622bc18a921f8bea166','dc167ace7074622bc18a921f8bea167','dc168ace7074622bc18a921f8bea168','dc169ace7074622bc18a921f8bea169','dc170ace7074622bc18a921f8bea170','dc171ace7074622bc18a921f8bea171','dc172ace7074622bc18a921f8bea172','dc173ace7074622bc18a921f8bea173','dc174ace7074622bc18a921f8bea174','dc175ace7074622bc18a921f8bea175','dc176ace7074622bc18a921f8bea176','dc177ace7074622bc18a921f8bea177','dc178ace7074622bc18a921f8bea178','dc179ace7074622bc18a921f8bea179','dc180ace7074622bc18a921f8bea180','dc181ace7074622bc18a921f8bea181','dc182ace7074622bc18a921f8bea182','dc183ace7074622bc18a921f8bea183','dc184ace7074622bc18a921f8bea184','dc185ace7074622bc18a921f8bea185','dc186ace7074622bc18a921f8bea186','dc187ace7074622bc18a921f8bea187','dc188ace7074622bc18a921f8bea188','dc189ace7074622bc18a921f8bea189','dc190ace7074622bc18a921f8bea190','dc191ace7074622bc18a921f8bea191','dc192ace7074622bc18a921f8bea192','dc193ace7074622bc18a921f8bea193','dc194ace7074622bc18a921f8bea194','dc195ace7074622bc18a921f8bea195','dc196ace7074622bc18a921f8bea196','dc197ace7074622bc18a921f8bea197','dc198ace7074622bc18a921f8bea198','dc199ace7074622bc18a921f8bea199')
 	, FingerprintCode = CONCAT(ELT(0.5 + RAND()*99,'df101aacddef6aaae06466b6757754413fcdc2a','df102aacddef6aaae06466b6757754413fcdc2a','df103aacddef6aaae06466b6757754413fcdc2a','df104aacddef6aaae06466b6757754413fcdc2a','df105aacddef6aaae06466b6757754413fcdc2a','df106aacddef6aaae06466b6757754413fcdc2a','df107aacddef6aaae06466b6757754413fcdc2a','df108aacddef6aaae06466b6757754413fcdc2a','df109aacddef6aaae06466b6757754413fcdc2a','df110aacddef6aaae06466b6757754413fcdc2a','df111aacddef6aaae06466b6757754413fcdc2a','df112aacddef6aaae06466b6757754413fcdc2a','df113aacddef6aaae06466b6757754413fcdc2a','df114aacddef6aaae06466b6757754413fcdc2a','df115aacddef6aaae06466b6757754413fcdc2a','df116aacddef6aaae06466b6757754413fcdc2a','df117aacddef6aaae06466b6757754413fcdc2a','df118aacddef6aaae06466b6757754413fcdc2a','df119aacddef6aaae06466b6757754413fcdc2a','df120aacddef6aaae06466b6757754413fcdc2a','df121aacddef6aaae06466b6757754413fcdc2a','df122aacddef6aaae06466b6757754413fcdc2a','df123aacddef6aaae06466b6757754413fcdc2a','df124aacddef6aaae06466b6757754413fcdc2a','df125aacddef6aaae06466b6757754413fcdc2a','df126aacddef6aaae06466b6757754413fcdc2a','df127aacddef6aaae06466b6757754413fcdc2a','df128aacddef6aaae06466b6757754413fcdc2a','df129aacddef6aaae06466b6757754413fcdc2a','df130aacddef6aaae06466b6757754413fcdc2a','df131aacddef6aaae06466b6757754413fcdc2a','df132aacddef6aaae06466b6757754413fcdc2a','df133aacddef6aaae06466b6757754413fcdc2a','df134aacddef6aaae06466b6757754413fcdc2a','df135aacddef6aaae06466b6757754413fcdc2a','df136aacddef6aaae06466b6757754413fcdc2a','df137aacddef6aaae06466b6757754413fcdc2a','df138aacddef6aaae06466b6757754413fcdc2a','df139aacddef6aaae06466b6757754413fcdc2a','df140aacddef6aaae06466b6757754413fcdc2a','df141aacddef6aaae06466b6757754413fcdc2a','df142aacddef6aaae06466b6757754413fcdc2a','df143aacddef6aaae06466b6757754413fcdc2a','df144aacddef6aaae06466b6757754413fcdc2a','df145aacddef6aaae06466b6757754413fcdc2a','df146aacddef6aaae06466b6757754413fcdc2a','df147aacddef6aaae06466b6757754413fcdc2a','df148aacddef6aaae06466b6757754413fcdc2a','df149aacddef6aaae06466b6757754413fcdc2a','df150aacddef6aaae06466b6757754413fcdc2a','df151aacddef6aaae06466b6757754413fcdc2a','df152aacddef6aaae06466b6757754413fcdc2a','df153aacddef6aaae06466b6757754413fcdc2a','df154aacddef6aaae06466b6757754413fcdc2a','df155aacddef6aaae06466b6757754413fcdc2a','df156aacddef6aaae06466b6757754413fcdc2a','df157aacddef6aaae06466b6757754413fcdc2a','df158aacddef6aaae06466b6757754413fcdc2a','df159aacddef6aaae06466b6757754413fcdc2a','df160aacddef6aaae06466b6757754413fcdc2a','df161aacddef6aaae06466b6757754413fcdc2a','df162aacddef6aaae06466b6757754413fcdc2a','df163aacddef6aaae06466b6757754413fcdc2a','df164aacddef6aaae06466b6757754413fcdc2a','df165aacddef6aaae06466b6757754413fcdc2a','df166aacddef6aaae06466b6757754413fcdc2a','df167aacddef6aaae06466b6757754413fcdc2a','df168aacddef6aaae06466b6757754413fcdc2a','df169aacddef6aaae06466b6757754413fcdc2a','df170aacddef6aaae06466b6757754413fcdc2a','df171aacddef6aaae06466b6757754413fcdc2a','df172aacddef6aaae06466b6757754413fcdc2a','df173aacddef6aaae06466b6757754413fcdc2a','df174aacddef6aaae06466b6757754413fcdc2a','df175aacddef6aaae06466b6757754413fcdc2a','df176aacddef6aaae06466b6757754413fcdc2a','df177aacddef6aaae06466b6757754413fcdc2a','df178aacddef6aaae06466b6757754413fcdc2a','df179aacddef6aaae06466b6757754413fcdc2a','df180aacddef6aaae06466b6757754413fcdc2a','df181aacddef6aaae06466b6757754413fcdc2a','df182aacddef6aaae06466b6757754413fcdc2a','df183aacddef6aaae06466b6757754413fcdc2a','df184aacddef6aaae06466b6757754413fcdc2a','df185aacddef6aaae06466b6757754413fcdc2a','df186aacddef6aaae06466b6757754413fcdc2a','df187aacddef6aaae06466b6757754413fcdc2a','df188aacddef6aaae06466b6757754413fcdc2a','df189aacddef6aaae06466b6757754413fcdc2a','df190aacddef6aaae06466b6757754413fcdc2a','df191aacddef6aaae06466b6757754413fcdc2a','df192aacddef6aaae06466b6757754413fcdc2a','df193aacddef6aaae06466b6757754413fcdc2a','df194aacddef6aaae06466b6757754413fcdc2a','df195aacddef6aaae06466b6757754413fcdc2a','df196aacddef6aaae06466b6757754413fcdc2a','df197aacddef6aaae06466b6757754413fcdc2a','df198aacddef6aaae06466b6757754413fcdc2a','df199aacddef6aaae06466b6757754413fcdc2a')
			,ELT(0.5 + RAND()*99,'df101oocddef6aaae06466b6757754413fcdc2a','df102oocddef6aaae06466b6757754413fcdc2a','df103oocddef6aaae06466b6757754413fcdc2a','df104oocddef6aaae06466b6757754413fcdc2a','df105oocddef6aaae06466b6757754413fcdc2a','df106oocddef6aaae06466b6757754413fcdc2a','df107oocddef6aaae06466b6757754413fcdc2a','df108oocddef6aaae06466b6757754413fcdc2a','df109oocddef6aaae06466b6757754413fcdc2a','df110oocddef6aaae06466b6757754413fcdc2a','df111oocddef6aaae06466b6757754413fcdc2a','df112oocddef6aaae06466b6757754413fcdc2a','df113oocddef6aaae06466b6757754413fcdc2a','df114oocddef6aaae06466b6757754413fcdc2a','df115oocddef6aaae06466b6757754413fcdc2a','df116oocddef6aaae06466b6757754413fcdc2a','df117oocddef6aaae06466b6757754413fcdc2a','df118oocddef6aaae06466b6757754413fcdc2a','df119oocddef6aaae06466b6757754413fcdc2a','df120oocddef6aaae06466b6757754413fcdc2a','df121oocddef6aaae06466b6757754413fcdc2a','df122oocddef6aaae06466b6757754413fcdc2a','df123oocddef6aaae06466b6757754413fcdc2a','df124oocddef6aaae06466b6757754413fcdc2a','df125oocddef6aaae06466b6757754413fcdc2a','df126oocddef6aaae06466b6757754413fcdc2a','df127oocddef6aaae06466b6757754413fcdc2a','df128oocddef6aaae06466b6757754413fcdc2a','df129oocddef6aaae06466b6757754413fcdc2a','df130oocddef6aaae06466b6757754413fcdc2a','df131oocddef6aaae06466b6757754413fcdc2a','df132oocddef6aaae06466b6757754413fcdc2a','df133oocddef6aaae06466b6757754413fcdc2a','df134oocddef6aaae06466b6757754413fcdc2a','df135oocddef6aaae06466b6757754413fcdc2a','df136oocddef6aaae06466b6757754413fcdc2a','df137oocddef6aaae06466b6757754413fcdc2a','df138oocddef6aaae06466b6757754413fcdc2a','df139oocddef6aaae06466b6757754413fcdc2a','df140oocddef6aaae06466b6757754413fcdc2a','df141oocddef6aaae06466b6757754413fcdc2a','df142oocddef6aaae06466b6757754413fcdc2a','df143oocddef6aaae06466b6757754413fcdc2a','df144oocddef6aaae06466b6757754413fcdc2a','df145oocddef6aaae06466b6757754413fcdc2a','df146oocddef6aaae06466b6757754413fcdc2a','df147oocddef6aaae06466b6757754413fcdc2a','df148oocddef6aaae06466b6757754413fcdc2a','df149oocddef6aaae06466b6757754413fcdc2a','df150oocddef6aaae06466b6757754413fcdc2a','df151oocddef6aaae06466b6757754413fcdc2a','df152oocddef6aaae06466b6757754413fcdc2a','df153oocddef6aaae06466b6757754413fcdc2a','df154oocddef6aaae06466b6757754413fcdc2a','df155oocddef6aaae06466b6757754413fcdc2a','df156oocddef6aaae06466b6757754413fcdc2a','df157oocddef6aaae06466b6757754413fcdc2a','df158oocddef6aaae06466b6757754413fcdc2a','df159oocddef6aaae06466b6757754413fcdc2a','df160oocddef6aaae06466b6757754413fcdc2a','df161oocddef6aaae06466b6757754413fcdc2a','df162oocddef6aaae06466b6757754413fcdc2a','df163oocddef6aaae06466b6757754413fcdc2a','df164oocddef6aaae06466b6757754413fcdc2a','df165oocddef6aaae06466b6757754413fcdc2a','df166oocddef6aaae06466b6757754413fcdc2a','df167oocddef6aaae06466b6757754413fcdc2a','df168oocddef6aaae06466b6757754413fcdc2a','df169oocddef6aaae06466b6757754413fcdc2a','df170oocddef6aaae06466b6757754413fcdc2a','df171oocddef6aaae06466b6757754413fcdc2a','df172oocddef6aaae06466b6757754413fcdc2a','df173oocddef6aaae06466b6757754413fcdc2a','df174oocddef6aaae06466b6757754413fcdc2a','df175oocddef6aaae06466b6757754413fcdc2a','df176oocddef6aaae06466b6757754413fcdc2a','df177oocddef6aaae06466b6757754413fcdc2a','df178oocddef6aaae06466b6757754413fcdc2a','df179oocddef6aaae06466b6757754413fcdc2a','df180oocddef6aaae06466b6757754413fcdc2a','df181oocddef6aaae06466b6757754413fcdc2a','df182oocddef6aaae06466b6757754413fcdc2a','df183oocddef6aaae06466b6757754413fcdc2a','df184oocddef6aaae06466b6757754413fcdc2a','df185oocddef6aaae06466b6757754413fcdc2a','df186oocddef6aaae06466b6757754413fcdc2a','df187oocddef6aaae06466b6757754413fcdc2a','df188oocddef6aaae06466b6757754413fcdc2a','df189oocddef6aaae06466b6757754413fcdc2a','df190oocddef6aaae06466b6757754413fcdc2a','df191oocddef6aaae06466b6757754413fcdc2a','df192oocddef6aaae06466b6757754413fcdc2a','df193oocddef6aaae06466b6757754413fcdc2a','df194oocddef6aaae06466b6757754413fcdc2a','df195oocddef6aaae06466b6757754413fcdc2a','df196oocddef6aaae06466b6757754413fcdc2a','df197oocddef6aaae06466b6757754413fcdc2a','df198oocddef6aaae06466b6757754413fcdc2a','df199oocddef6aaae06466b6757754413fcdc2a')
			)
	, UserAgent = (SELECT  t.UserAgent FROM Temp_DataUserAgent t WHERE id = FLOOR(RAND()*(120-1)+1 ) LIMIT 1)
WHERE TransID > 22 and UserAgent Is NULL
;
Insert into RawTransaction (LoginName,SubscriberName,TransTime,CreatedDate,DeviceCode,FingerprintCode,FingerprintMoreInfo,UserAgent,IP,IPID,PluginID,URL,Action,ActionResult,InvalidDevice,TransStatus,FPSTransID,Flagged,IsProcessed,InsertTime,BotDetectionValue,BotComponentID)SELECT LoginName,SubscriberName,TransTime,CreatedDate,DeviceCode,FingerprintCode,FingerprintMoreInfo,UserAgent,IP,IPID,PluginID,URL,Action,ActionResult,InvalidDevice,TransStatus,FPSTransID,Flagged,IsProcessed,InsertTime,BotDetectionValue,BotComponentID FROM RawTransaction_bk;

SELECT COUNT(1) FROM RawTransaction WHERE IsProcessed = 0;
SELECT COUNT(1) FROM Transaction ;
SELECT COUNT(1) FROM Transaction07;
SELECT COUNT(1) FROM ProcessedTransaction;


SELECT FLOOR(RAND()*(120-1)+1 );
SELECT ID, length(UserAgent), UserAgent FROM Temp_UserAgent WHERE UserAgent is null;
SELECT t.UserAgent, t.* FROM RawTransaction t WHERE UserAgent is null;



#====================================================
SELECT * FROM SystemSetting;
SELECT * FROM DCS_Extra.AccountDevice;
SELECT * FROM DCS_Extra.AccountLastLoginTimeProcess;
SELECT * FROM DCS_Extra.ActionResult;
SELECT * FROM DCS_Extra.Association;
SELECT * FROM DCS_Extra.Device;
SELECT * FROM DCS_Extra.DeviceCode;
SELECT * FROM DCS_Extra.DeviceFingerprint;
SELECT * FROM DCS_Extra.DeviceType;
SELECT * FROM DCS_Extra.OS;
SELECT * FROM DCS_Extra.ProcessedTransaction;
SELECT * FROM DCS_Extra.Subscriber;
SELECT * FROM DCS_Extra.Transaction;
SELECT * FROM DCS_Extra.Transaction07;
SELECT * FROM DCS_Extra.URL;
SELECT * FROM DCS_Extra.UserAgent;
SELECT TransStatus, IsProcessed, TransID, r.* FROM RawTransaction r; 

UPDATE SystemSetting SET VValue = '2001-01-01' WHERE ID = 2;
UPDATE SystemSetting SET VValue = 0 WHERE ID = 1;
UPDATE SystemSetting SET VValue = 0 WHERE ID = 3;

#========2. TRANSFORM ACCOUNT Service DCS_TransformTransaction_Job: from Table RawTransaction TO Table Transaction===============================================
	#2.1 Service Call:
    CALL DCS_Extra.DCS_ET_Transform_RawTrans_GetPackage(@ip_IsProcessed:=0, @ip_NoOfTickets:=10, @ip_NoOfBatch:=2); 
	
    SELECT * FROM SystemSetting WHERE ID = 3; #Expected: value = SELECT MIN(transID) FROM RawTransaction WHERE  IsProcessed = 0;

	#=====2.1.a TRANSFORM BATCH 1;
		CALL DCS_ET_Transform_UnhandleSubscriberAction(@ip_FromTransID:=1, @ip_ToTransID:=10);
			Check SELECT TransStatus, IsProcessed, TransID, r.* FROM RawTransaction r; SELECT * FROM DCS_Extra.ActionResult;
        CALL DCS_ET_Transform_UserAgent_Insert(@ip_FromTransID:=1, @ip_ToTransID:=10); 
			Check SELECT * FROM UserAgent;
        CALL DCS_ET_Transform_Transaction_Insert(@ip_FromTransID:=11, @ip_ToTransID:=147); 
			SELECT * FROM Account; 
            SELECT * FROM AccountLastLoginTimeProcess ; --> Insert Exsisting Account to update LastLoginTime
            SELECT transid, rawtransid, t.* FROM Transaction t; ---> Insert 
            SELECT * FROM ProcessedTransaction; --> Insert 
            SELECT TransID, IsProcessed, TransStatus, r.* FROM RawTransaction r;
SELECT  *
	FROM		DCS_Extra.RawTransaction AS rt
        #INNER JOIN	DCS_Extra.Subscriber AS su ON	rt.SubscriberName = su.SubscriberName
	    INNER JOIN	DCS_Extra.ActionResult AS ar ON	rt.Action = ar.Action AND IFNULL(rt.ActionResult,'') = ar.ActionResult
	WHERE   rt.IsProcessed = 0
	    AND rt.TransID BETWEEN 11 AND 147;
       # AND rt.CreatedDate 	>=	'2001-01-01 00:00:00';
    #=====2.1.b TRANSFORM BATCH 2
		CALL DCS_ET_Transform_UnhandleSubscriberAction(@ip_FromTransID:=11, @ip_ToTransID:=167); 
        CALL DCS_ET_Transform_UserAgent_Insert(@ip_FromTransID:=11, @ip_ToTransID:=167);
        CALL DCS_ET_Transform_Transaction_Insert(@ip_FromTransID:=11, @ip_ToTransID:=167); 

	#2.2 Next round Service Call:
	CALL DCS_Extra.DCS_ET_Transform_RawTrans_GetPackage(@ip_IsProcessed:=0, @ip_NoOfTickets:=10, @ip_NoOfBatch:=2); 
    .....
    
    SELECT *     FROM DCS_Extra.TransStatus;
    0
1
2
4
8
16;
    UPDATE TransStatus 
    SET StatusValue = 0
    WHERE TransStatusName = 'Valid Transaction' ; 
    
		              Update    
#========3. TRANSFORM DEVICE: from Table Transaction TO Table Transaction07===============================================        
CALL DCS_ET_Transform_Device_GetPackage(@ip_NoOfTickets:=10, @ip_NoOfBatch:=2);
	#3.a TRANSFROM BATCH 1
    CALL `DCS_ET_Transform_Device_Insert`(@ip_TransJson:='[{"TransId":1},{"TransId":2},{"TransId":3},{"TransId":4},{"TransId":5},{"TransId":6},{"TransId":7},{"TransId":8},{"TransId":9},{"TransId":10}]');    
    SELECT * FROM Device;
    SELECT * FROM DeviceCode;
    SELECT * FROM DeviceFingerprint;
    SELECT * FROM Association;
    SELECT * FROM Transaction07;
	SELECT * FROM Transaction;
    
    #3.b TRANSFROM BATCH 2
    CALL `DCS_ET_Transform_Device_Insert`(@ip_TransJson:='[{"TransId":16},{"TransId":17},{"TransId":18},{"TransId":19},{"TransId":20},{"TransId":21},{"TransId":22},{"TransId":23},{"TransId":24}]');  
    
SELECT TransId FROM Transaction;
#========4. TRANSFORM USER AGENT: from Table Transaction TO Table Transaction07===============================================        
 CALL DCS_ET_Transform_UserAgent_GetNullBrowserOSList(@ip_size:=10); 
CALL DCS_ET_Transform_UserAgent_UpdateOSBrowser  (@ip_UserAgentJson:='[
	{"UserAgentKey":"308eece5f357f045ed4a4c5091c7a802","UserAgent":"Mozilla/5.0 (iPhone; CPU iPhone OS 15_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Mobile/15E148 Safari/604.1","CreatedDate":"2023-06-29 00:00:00"}
,	{"UserAgentKey":"58f72e5001152d7391f935c46d539c35","UserAgent":"Mozilla/5.0 (Linux; Android 11; CPH2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Mobile Safari/537.36","CreatedDate":"2023-06-29 00:00:00"}
]
');
SELECT * FROM DeviceType;
SELECT * FROM OS;
SELECT * FROM Browser;
SELECT * FROM UserAgent;

#===========5. Update LastLoginTime for DCS_extra Account
Event Name: SHOW EVENTS; EV_DCS_Extra_Account_UpdateLastLoginTime; Interval 4s
SP: CALL DCS_Extra.DCS_ET_Transform_Account_UpdateLastLoginTime(1000); 
