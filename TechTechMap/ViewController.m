//
//  ViewController.m
//  TechTechMap
//
//  Created by Yamasaki Shintaro on 2015/10/21.
//  Copyright © 2015年 Yamasaki Shintaro. All rights reserved.
//

#import "ViewController.h"



@import CoreBluetooth;


@interface ViewController ()
<CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate>
{
    BOOL isScanning;
    NSArray *serviceUUIDs;
    NSMutableDictionary *dictSubText;
    NSMutableDictionary *dictWriteWord;
    NSMutableDictionary *dictCharacteristic;
    NSUserDefaults *userDefault;
    
}
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) IBOutlet UILabel *lblLog;
@property (nonatomic, strong) IBOutlet UITextField *txtLocation;
@property (nonatomic, strong) IBOutlet UILabel *lblRSSI;
@property (nonatomic, strong) IBOutlet UISlider *sldRSSI;
@property (nonatomic) IBOutlet UITableView *tblPeripheral;
@property (nonatomic) IBOutlet UIStepper *stpPInterval;
@property (nonatomic) IBOutlet UILabel *lblPInterval;
@end


@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];
    
    // ユーザーデフォルト
    userDefault = [NSUserDefaults standardUserDefaults];
    if ([[userDefault stringForKey:@"LOCATION"] isEqual:@""]) {
        self.txtLocation.text = @"0";
    } else {
        self.txtLocation.text = [userDefault stringForKey:@"LOCATION"];
    }
    
    self.lblLog.text = @"";
    
    self.peripherals = [NSMutableArray array];
    serviceUUIDs = [NSArray arrayWithObjects:[CBUUID UUIDWithString:kServiceUUID], nil];
    
    self.lblPInterval.text = [NSString stringWithFormat:@"%d", (int)self.stpPInterval.value];

    
    dictSubText = [NSMutableDictionary dictionary];
    dictWriteWord = [NSMutableDictionary dictionary];
    dictCharacteristic = [NSMutableDictionary dictionary];
    
    // テーブル
    self.tblPeripheral.delegate = self;
    self.tblPeripheral.dataSource = self;
    
    // RSSIスライダー
    if ([userDefault integerForKey:@"RSSI"] == 0) {
        self.sldRSSI.value = 70;
    } else {
        self.sldRSSI.value = [userDefault integerForKey:@"RSSI"];
    }
    [self.sldRSSI addTarget:self action:@selector(changeSlider:) forControlEvents:UIControlEventValueChanged];
    [self showSliderValue];
  
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/// ログ表示
- (void) showLog: (NSString *) log {
    self.lblLog.text = log;
    NSLog(@"%@", log);
    
    [self publishLocalNotificationWithMessage:log];
}

// ローカル通知を発行する（バックグラウンドのみ）
- (void)publishLocalNotificationWithMessage:(NSString *)message {
    
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        
        UILocalNotification *localNotification = [UILocalNotification new];
        localNotification.alertBody = message;
        localNotification.fireDate = [NSDate date];
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
}

#pragma mark - IBAction
// スキャンボタン
- (IBAction)scanBtnTapped:(UIButton *)sender {
    
    if (!isScanning) {
        
        isScanning = YES;
        
        // ユーザーデフォルト
        [userDefault setObject:self.txtLocation.text forKey:@"LOCATION"];
        [userDefault synchronize];
        
        // スキャン開始
//        [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:nil];
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        [self.tblPeripheral reloadData];
        
        
        // パーソナリティ情報取得
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            while (isScanning) {
                [self getParsonalityInfo];
                sleep(self.stpPInterval.value);
            }
        });

        
        
        // ログ
        [self showLog:@"Start Scan"];
    }
    else {
        
        // スキャン停止
        [self.centralManager stopScan];
        
        [sender setTitle:@"Start" forState:UIControlStateNormal];
        isScanning = NO;
        
        [self.peripherals removeAllObjects];
        self.peripherals = [NSMutableArray array];
        
        // ログ
        [self showLog:@"Stop Scan"];
        
        [self.tblPeripheral reloadData];
    }
}

// パーソナリティ情報取得インターバル
- (IBAction)changeStepper:(id)sender {
    self.lblPInterval.text = [NSString stringWithFormat:@"%d", (int)self.stpPInterval.value];
}

#pragma mark - UISlider
// 値変更
- (void) changeSlider: (UISlider*)slider {
    [userDefault setInteger:slider.value forKey:@"RSSI"];
    
    [self showSliderValue];
}

// ラベル表示
- (void) showSliderValue {
    self.lblRSSI.text = [NSString stringWithFormat:@"%f", self.sldRSSI.value];
}


#pragma mark - Write
/// 書き込み
- (void) write: (CBPeripheral *) peripheral {
    // 先頭に長さ情報を付加
    NSData *txt = [[dictWriteWord objectForKey:peripheral.identifier.UUIDString] dataUsingEncoding:NSASCIIStringEncoding];
    
    const unsigned char *ptr = [txt bytes];
    unsigned char value[512];
    value[0] = 0x05;
    value[1] = 0x00;
    value[2] = 0x00;
    value[3] = 0x00;
    
    long dataLength = [txt length];
    for(int i = 4; i - 4 < dataLength; i++) {
        unsigned char c = *ptr++;
        value[i] = c;
        NSLog(@"char=%c hex=%x", c, c);
    }
    NSLog(@"%s", value);
    
    NSData *data = [[NSData alloc] initWithBytes:&value length:dataLength + 4];

    
    // 書き込み
    [peripheral writeValue:data
         forCharacteristic:[dictCharacteristic objectForKey:peripheral.identifier.UUIDString]
                           type:CBCharacteristicWriteWithResponse];
    
    NSLog(@"%@", [dictWriteWord objectForKey:peripheral.identifier.UUIDString]);

}

#pragma mark - POST
// サーバーへポストする
- (void) postIDs: (NSString *) UUID Location: (NSString *) loc {
    // 送信したいURLを作成する
    NSURL *url = [NSURL URLWithString:@"http://52.68.204.205:3000/beacons"];
    // Mutableなインスタンスを作成し、インスタンスの内容を変更できるようにする
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    // MethodにPOSTを指定する。
    request.HTTPMethod = @"POST";
    
    // 送付したい内容を、key1=value1&key2=value2・・・という形の
    // 文字列として作成する
    if ([loc hasPrefix:@"l"]) {
        loc = [loc stringByReplacingOccurrencesOfString:@"l" withString:@""];
    }
    NSString *body = [NSString stringWithFormat:@"device=%@&location=%@", UUID, loc];
    
    // HTTPBodyには、NSData型で設定する
    request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    
    //同期通信で送信
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error != nil) {
        NSLog(@"Error!%@", error);
        return;
    }
    
    NSError *e = nil;
    
    //取得したレスポンスをJSONパース
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:nil error:&e];
    
    NSLog(@"%@", dict);
//    NSString *token = [dict objectForKey:@"token"];
//    NSLog(@"Token is %@", token);
}

// パーソナリティ情報取得
- (void) getParsonalityInfo {
    // 送信したいURLを作成する
    NSURL *url = [NSURL URLWithString:@"http://52.68.204.205:3000/beacons?device=personality"];
    // Mutableなインスタンスを作成し、インスタンスの内容を変更できるようにする
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    // MethodにPOSTを指定する。
    request.HTTPMethod = @"GET";
    
    
    //同期通信で送信
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (error != nil) {
        NSLog(@"Error!%@", error);
        return;
    }
    
    NSError *e = nil;
    
    //取得したレスポンスをJSONパース
    NSArray *aryjson = [NSJSONSerialization JSONObjectWithData:data options:nil error:&e];
    
    NSLog(@"%@", aryjson);
    
    // 接続中のペリフェラルに書き込み
    NSDictionary *p_dict = [aryjson lastObject];
    NSString *p_loc = [p_dict objectForKey:@"location"];
    for (CBPeripheral *peripheral in self.peripherals) {
        if (peripheral.state == CBPeripheralStateConnected) {
            if ([dictCharacteristic objectForKey:peripheral.identifier.UUIDString] != nil) {
                NSString *command = [@"p" stringByAppendingString:p_loc];
                [dictWriteWord setObject:command forKey:peripheral.identifier.UUIDString];
                [self write:peripheral];
            }
        }
    }

}


#pragma mark - CBCentralManagerDelegate
// セントラルマネージャの状態が変化すると呼ばれる
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // 特に何もしない
    NSLog(@"centralManagerDidUpdateState:%ld", (long)central.state);
}

// ペリフェラルを発見すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    // NameがIMBLE0083なら接続
    if (![peripheral.name hasPrefix:@"IMBLE"]) return;
    
    NSLog(@"Map：%@", peripheral);
    
    if (peripheral.state == CBPeripheralStateDisconnected) {
        [self.peripherals addObject: peripheral];
        [dictSubText setObject:@"" forKey:peripheral.identifier.UUIDString];
        [dictWriteWord setObject:@"" forKey:peripheral.identifier.UUIDString];
    }
    
    // 接続開始
    [self.centralManager connectPeripheral:peripheral
                                   options:nil];

    // ログ
    [self showLog:@"Start Connect"];
}

/// 接続成功すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // ログ
    [self showLog:@"Success Connect"];
    
    // テーブル更新
    [self.tblPeripheral reloadData];
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:nil];
}

/// 切断成功するとよばれる
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self showLog:@"Disconnect"];
    
    if (error) {
        NSLog(@"%@", error);
        
        [self.centralManager connectPeripheral:peripheral options:nil];
        
        return;
    }
    
    // 解放
    [self.peripherals removeObject:peripheral];
    [dictSubText removeObjectForKey:peripheral.identifier.UUIDString];
    [dictWriteWord removeObjectForKey:peripheral.identifier.UUIDString];
    
    // テーブル更新
    [self.tblPeripheral reloadData];
    
}

// 接続失敗すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {

    // ログ
    [self showLog:@"Fault Connect"];

}

#pragma mark - CBPeripheralDelegate

// サービス発見時に呼ばれる
- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *services = peripheral.services;
    NSLog(@"%lu 個のサービスを発見！:%@", (unsigned long)services.count, services);

    
    for (CBService *service in services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            // ログ
            [self showLog:@"Search Characteristics"];
            
            // キャラクタリスティック探索開始
            [peripheral discoverCharacteristics:nil forService:service];
        }
        
    }
}

// キャラクタリスティック発見時に呼ばれる
- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *characteristics = service.characteristics;
    NSLog(@"%lu 個のキャラクタリスティックを発見！%@", (unsigned long)characteristics.count, characteristics);
    
    for (CBCharacteristic *characteristic in characteristics) {
        
        // Write専用のキャラクタリスティック
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kWriteUUID]]) {
            // 格納
            [dictCharacteristic setObject:characteristic forKey:peripheral.identifier.UUIDString];
            
            // RSSIチェック
            [peripheral readRSSI];
        }

    }
    
    [peripheral readRSSI];
}

// データ書き込みが完了すると呼ばれる
- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Write失敗...error:%@", error);
        return;
    }
    
    // ログ
    [self showLog:[NSString stringWithFormat: @"Success Write: %@", [dictWriteWord objectForKey:peripheral.identifier.UUIDString]]] ;
    
    // 書き込み場合分け
    // location
    if ([[dictWriteWord objectForKey:peripheral.identifier.UUIDString] hasPrefix:@"l"]) {
        // 接続切断
        [self.centralManager cancelPeripheralConnection:peripheral];
        
        // DBへ書き込み
        // UUID, loc
        NSString *UUID = peripheral.identifier.UUIDString;
        NSString *loc = self.txtLocation.text;
        [self postIDs: UUID Location: loc];
    }
    
    

}

// RSSI更新
- (void) peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    NSLog(@"RSSI %d %@", RSSI.intValue, peripheral.identifier.UUIDString);
    
    [dictSubText setObject:[NSString stringWithFormat:@"%d", RSSI.intValue] forKey: peripheral.identifier.UUIDString];
    [self.tblPeripheral reloadData];
    
    // もう一度読み込む
    if (RSSI.intValue < -self.sldRSSI.value) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            sleep(0.4);
            [peripheral readRSSI];
        });
        
        return;
    }
    
    // ログ
    [self showLog:@"Start Write"];
    
    // 書き込み
    [self write:peripheral];
    // 書き込みワード指定
    [dictWriteWord setObject:self.txtLocation.text forKey:peripheral.identifier.UUIDString];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger dataCount;
    
    // テーブルに表示するデータ件数を返す
    switch (section) {
        case 0:
            dataCount = self.peripherals.count;
            break;
        default:
            break;
    }
    return dataCount;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    // 再利用できるセルがあれば再利用する
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell) {
        // 再利用できない場合は新規で作成
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.numberOfLines = 2;
    
    CBPeripheral *peripheral = [self.peripherals objectAtIndex:indexPath.row];
    NSString *UUID = peripheral.identifier.UUIDString;
    
    // ステータスで色を変える
    switch (peripheral.state) {
        case CBPeripheralStateConnected:
        case CBPeripheralStateConnecting:
            
            cell.textLabel.textColor = [UIColor blueColor];
            break;
        case CBPeripheralStateDisconnected:
        case CBPeripheralStateDisconnecting:
            cell.textLabel.textColor = [UIColor redColor];
            break;
        default:
            cell.textLabel.textColor = [UIColor blackColor];
            break;
    }
    
    cell.textLabel.font = [UIFont fontWithName:@"AppleGothic" size:10];
    
    switch (indexPath.section) {
        case 0:
            cell.textLabel.text = [NSString stringWithFormat:@"%@\n%@", UUID, [dictSubText objectForKey:peripheral.identifier.UUIDString]];
            break;
        default:
            break;
    }
    
    return cell;
}



@end

