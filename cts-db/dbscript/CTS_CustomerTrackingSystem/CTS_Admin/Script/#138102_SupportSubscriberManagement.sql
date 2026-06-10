#[20200911@Roger.Le][138102]: Function add new subscriber
ALTER TABLE CTS_Admin.Subscriber ADD COLUMN TerminatedDate DATETIME DEFAULT NULL;
ALTER TABLE CTS_Admin.Subscriber MODIFY `SubscriberPrefix` VARCHAR(30) DEFAULT NULL;
CREATE INDEX IX_Subscriber_SubscriberPrefix ON CTS_Admin.Subscriber (SubscriberPrefix);

#[20200925@Lex.Khuat][138102]: Function add new subscriber with multi site
CREATE INDEX IX_MappingSubscriberSite_SubscriberID ON CTS_DataCenter.MappingSubscriberSite (SubscriberID);

# Add more log info
INSERT INTO CTS_Admin.LogType(LogTypeID, LogTypeName, LogTypeDescription)
VALUES
(23, 'Remove site mapping', 'Delete site mapping'),
(24, 'Update site mapping', 'Update site mapping'),
(25, 'Insert site mapping', 'Insert site mapping'),
(26, 'Terminate Subscriber', 'Terminate Subscriber'),
(27, 'Update Subscriber', 'Update Subscriber'),
(28, 'Insert Subscriber', 'Insert Subscriber');