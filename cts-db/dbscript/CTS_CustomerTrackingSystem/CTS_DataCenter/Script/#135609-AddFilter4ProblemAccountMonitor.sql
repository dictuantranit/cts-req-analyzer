/*
Created: 20200518@lex.khuat
		Task:		Update robot description from Green to Human [Redmine ID: #133934]
		DB:			CTS_DataCenter
		Original:
		Revisions:
/*

/****=====Step=====****/

# Init subscribergroup data
SET @INSERT_TIME = CURRENT_TIMESTAMP();
INSERT INTO CTS_DataCenter.SubscriberGroup(SubscriberGroupName, SubscriberGroupDesc, ParentID, DisplayOrder, IsActive, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy)
VALUES
('Credit', 'All credit subscribers', 0, 1, 1, @INSERT_TIME, null, @INSERT_TIME, null),
('Licensees', 'All licensee subscribers', 0, 2, 1, @INSERT_TIME, null, @INSERT_TIME, null),
('CN88', 'All CN88 subscribers', 0, 3, 1, @INSERT_TIME, null, @INSERT_TIME, null);

# Backup tbl MappingSubscriberSite to Adhoc database
CREATE TABLE CTS_Adhoc.zzzBK_MappingSubscriberSite LIKE CTS_DataCenter.MappingSubscriberSite;
INSERT CTS_Adhoc.zzzBK_MappingSubscriberSite
SELECT *
FROM CTS_DataCenter.MappingSubscriberSite;

# Add column SubscriberGroupID into tbl MappingSubscriberSite
ALTER TABLE CTS_DataCenter.MappingSubscriberSite
ADD COLUMN SubscriberGroupID SMALLINT UNSIGNED AFTER SubscriberStatus;

# UPDATE data groupID
SET SQL_SAFE_UPDATES = 0;

# Update groupID for CN88
UPDATE CTS_DataCenter.MappingSubscriberSite
SET SubscriberGroupID = 3
WHERE SubscriberGroupID is null
AND SiteID = 329; # CN88

# Update groupID for mapped licensees
UPDATE CTS_DataCenter.MappingSubscriberSite
SET SubscriberGroupID = 2
WHERE SubscriberGroupID is null
AND SiteID in (
         48      # Bodog
        ,30      # 12Bet
        ,36      # alog
        ,34      # mansion88
        ,42      # Zzun88
        ,44      # haifa
        ,31      # asiabet88
        ,38      # TLC
        ,40      # SunGame
        ,55      # VCasia
        ,53      # Macaubet
        ,98      # 9bet
        ,94      # W88
        ,56      # Aoncash
        ,58      # ITCbet
        ,101      # 3star88
        ,118      # Salon365
        ,111      # 88Macao
        ,110      # Boma365
        ,37      # spondemo
        ,134      # M8bola
        ,144      # BE7
        ,104      # OLE777
        ,125      # 368Cash
        ,133      # AG
        ,128      # Happy1668
        ,145      # iBET
        ,127      # Royal
        ,126      # Senibet
        ,138      # 9Club
        ,123      # Ae88
        ,142      # HONBET
        ,137      # KeenOcean
        ,139      # XTD3
        ,165      # IBO
        ,150      # GooBet
        ,143      # Q8bola
        ,182      # Abcasino
        ,178      # AsianBet
        ,177      # DBP
        ,169      # Empire555
        ,171      # GamingSoft
        ,176      # Hecbet
        ,180      # HL8
        ,161      # HonorW
        ,152      # Liga
        ,158      # NBCbet
        ,173      # Newhonbet
        ,183      # TGO
        ,170      # Unobet
        ,191      # 365online
        ,163      # DEWA
        ,199      # Gampag
        ,204      # HuangMa
        ,198      # IONclub
        ,155      # ISC888
        ,194      # KhmerG
        ,201      # Mayayule
        ,200      # Sun988
        ,205      # webet88
        ,217      # VCBA
        ,218      # Taipanbet
        ,225      # Dawoo
        ,221      # FLC
        ,214      # PKbet
        ,224      # TGame
        ,196      # Bolanation
        ,222      # IGPTech
        ,230      # IvoryBet
        ,207      # BigGaming
        ,208      # Boying
        ,235      # Uwoniwin
        ,234      # Opal88
        ,236      # Sunrise
        ,237      # Swin
        ,239      # UN168
        ,240      # PanguGame
        ,241      # ECLBET
        ,242      # K8VN
        ,212      # Brown888
        ,245      # GPIGAME
        ,246      # 818Bet
        ,250      # Bobo88
        ,248      # Heaven
        ,256      # Okada
        ,251      # OPEBET
        ,253      # Sunriseb2b
        ,259      # 396Club
        ,260      # Mybet88
        ,269      # MAX88
        ,270      # BBIN2
        ,271      # YongBao
        ,278      # 11bet
        ,275      # ALPHA88
        ,274      # GMASTER
        ,277      # Tripleone
        ,283      # 9wickets
        ,284      # Aplus
        ,280      # ENTAPLAY
        ,281      # MICL
        ,282      # zt828
        ,261      # e8casino
        ,293      # BETSUN
        ,291      # FB88
        ,295      # HOT88
        ,297      # Monaco
        ,287      # WBS
        ,292      # Xinbo
        ,289      # YBTech
        ,290      # Yibo
        ,244      # Lucky88
        ,298      # Opadmin
        ,299      # Bonanza88
        ,301      # JIBET
        ,305      # Dade
        ,307      # Fabet
        ,308      # Gameroom
        ,304      # MARS
        ,306      # Nbbet
        ,300      # SSSGaming
        ,302      # WINCLUB88
        ,309      # ANGbet
        ,310      # Callmeboss
        ,215      # CGame
        ,263      # HongChow
        ,312      # One88
        ,265      # TangChao
        ,317      # A1game
        ,314      # BetDeal
        ,320      # gbkj
        ,318      # HJTK
        ,313      # Hong88
        ,321      # skykey
        ,319      # TitanOne
        ,315      # VWIN66
        ,327      # 18Luck
        ,334      # AMG
        ,323      # Bobbet
        ,332      # HCVIP
        ,333      # ig128
        ,330      # Kudatogel
        ,328      # Mbet
        ,335      # MRCATSB
        ,336      # VN88
        ,326      # XinYo
        ,325      # AEUG
        ,340      # Debet
        ,341      # Kraton
        ,338      # Sin88
        ,187      # Starnet
        ,337      # TXG
        ,339      # Zbet
        ,345      # Gaobet
        ,346      # GGBOOK
        ,351      # HeleThai
        ,342      # Pinbo
        ,350      # shicaigw
        ,344      # Sunwin
        ,347      # UwinY
        ,348      # YAYOU
        ,364      # AnvoFH
        ,359      # Champion
        ,362      # DF88
        ,357      # Five88
        ,363      # GESAB
        ,356      # Hongtubet
        ,353      # IBG
        ,352      # Onegaming
        ,358      # Raisetech
        ,361      # sbt88
        ,360      # txwl002
        ,370      # Calibet
        ,375      # Leng4D
        ,376      # tcycyl
        ,372      # weicai
        ,366      # WKCUR
        ,368      # WKPHIL
        ,377      # Xtu168
        ,398      # Asian88
        ,397      # DingTai
        ,373      # Luckywin88
        ,389      # TopGame
        ,402      # BBIN3
        ,403      # ENT22
        ,388      # Mopgaming
        ,400      # Winn69
        ,408      # B24VN
        ,407      # ID88
        ,405      # INSERTGAME
        ,406      # Yabo3
        ,418      # 24AVIA
        ,412      # allwincity
        ,417      # Apollo
        ,410      # BBIN4
        ,415      # BOG22
        ,413      # BWGaming
        ,414      # KingBet
        ,416      # Wanfang
        ,411      # BOSSB
        ,423      # Datang
        ,354      # Happy8
        ,419      # KUTECH
        ,421      # Siamgame
        ,422      # WBG88
        ,430      # 88Goals
        ,429      # Bobbet2
        ,427      # erhaozhan
        ,428      # JIDU
        ,425      # NewFuture
        ,424      # Spark
        ,426      # YTX
        ,438      # 568Win
        ,444      # 633esports
        ,433      # 7Konline
        ,441      # CGame4
        ,442      # Datang001
        ,435      # G2Win
        ,443      # Jarvis
        ,436      # MTech
        ,434      # PKKing
        ,440      # shengboyun
        ,437      # Wanbo
        ,450      # GPgaming88
        ,448      # N88
        ,446      # Newbet
        ,445      # starsoccer
        ,449      # WB101
        ,452      # hjccasino
        ,454      # OCMS
        ,453      # Red88
        ,463      # 9Wsports
        ,456      # afb99
        ,459      # DTGW
        ,460      # JGQP8
        ,455      # Lode88
        ,462      # mtegames
        ,457      # Soon88
        ,432      # WKIBPH
        ,458      # XTDGT
        ,468      # dabo88
        ,471      # LLGAME
        ,465      # OneSports
        ,469      # Tianbo
        ,470      # TitanCraft
        ,466      # WUYICP
        ,464      # Yunji
        ,472      # Storm88
        ,474      # Sunbet138
        ,473      # TCbet
        ,479      # Heji888
        ,476      # JZFortune
        ,475      # TaoCai
        ,480      # TYCgame
        ,477      # ZhiFeng032
        ,371      # Ｗin88
        ,478      # HBO999
        ,483      # N8B
        ,482      # N8G
        ,481      # Zowin
        ,401      # Axiawin
        ,485      # BPLE
        ,484      # GGBOOKES
        ,486      # Weiwei
        ,489      # MFgame
        ,488      # ZhiFeng035
        ,491      # ZhiFeng009
        ,490      # ZhiFeng036
        ,492      # awc
        ,493      # SV88
        ,494      # Junbet
        ,495      # awc2
        ,496      # M8Credit
        ,497      # Bsdbet
        ,498      # ZFRT081
        ,499      # 998bet
        ,504      # MANBETX
        ,503      # ZhiFeng012
        ,505      # ZFRT082
        ,506      # wmcasino
        ,507      # Winbox
        ,508      # pmwint
        ,509      # ZhiFeng021
		,510      # liv66	
        ,511      # HC6YAYOU	
        ,512      # TIC88	
        ,513      # Nbet	
        ,514      # Sky88	
        ,515      # Kbet	
        ,516      # Dabet	
);

# Update groupID for mapped credit
UPDATE CTS_DataCenter.MappingSubscriberSite
SET SubscriberGroupID = 1
WHERE SubscriberGroupID is null
AND SiteID in (
         32      # 33333
        ,23      # 222223
        ,24      # 222225
        ,25      # 222227
        ,16      # 611111
        ,20      # 722222
        ,21      # 733333
        ,22      # 755555
        ,184      # 766666
        ,3      # 789y
        ,188      # 7aa666
        ,1      # BEST-ODDS
        ,294      # EU88
        ,147      # IMBC
        ,11      # INDO
        ,109      # JPNIBC
        ,66      # JPNIBC
        ,35      # KORIBC
        ,29      # spotico
        ,13      # XYZBET
        ,487      # IBCIndo
);

SET SQL_SAFE_UPDATES = 1;

/*====================*/