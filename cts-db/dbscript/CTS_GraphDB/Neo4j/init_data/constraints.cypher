// 4.2.x
CREATE CONSTRAINT Evidence_KEY IF NOT EXISTS ON (evidence:Evidence) ASSERT evidence.EvidenceID IS UNIQUE;
CREATE CONSTRAINT Subscriber_KEY IF NOT EXISTS ON (subscriber:Subscriber) ASSERT subscriber.SubscriberID IS UNIQUE;
CREATE CONSTRAINT Site_KEY IF NOT EXISTS ON (site:Site) ASSERT site.SiteID IS UNIQUE;
CREATE CONSTRAINT Customer_KEY IF NOT EXISTS ON (customer:CTSCustomer) ASSERT customer.CTSCustID IS UNIQUE;
CREATE CONSTRAINT Device_KEY IF NOT EXISTS ON (device:Device) ASSERT device.DeviceID IS UNIQUE;
CREATE CONSTRAINT Category_KEY IF NOT EXISTS ON (category:CustomerCategory) ASSERT n.CategoryID IS UNIQUE;

//4.0.x
CREATE CONSTRAINT Evidence_KEY ON (evidence:Evidence) ASSERT evidence.EvidenceID IS UNIQUE;
CREATE CONSTRAINT Subscriber_KEY ON (subscriber:Subscriber) ASSERT subscriber.SubscriberID IS UNIQUE;
CREATE CONSTRAINT Site_KEY ON (site:Site) ASSERT site.SiteID IS UNIQUE;
CREATE CONSTRAINT Customer_KEY ON (customer:CTSCustomer) ASSERT customer.CTSCustID IS UNIQUE;
CREATE CONSTRAINT Device_KEY ON (device:Device) ASSERT device.DeviceID IS UNIQUE;
CREATE CONSTRAINT Category_KEY ON (category:CustomerCategory) ASSERT n.CategoryID IS UNIQUE;