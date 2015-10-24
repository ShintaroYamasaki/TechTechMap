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
<CBCentralManagerDelegate, CBPeripheralDelegate>
{
    BOOL isScanning;
    NSString *placeID;
}
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *outputCharacteristic;
@property (nonatomic, strong) CBCharacteristic *inputCharacteristic;
@property (nonatomic, strong) IBOutlet UILabel *lblLog;
@property (nonatomic, strong) IBOutlet UILabel *lblID;
@property (nonatomic, strong) IBOutlet UITextField *txtPlaceID;
@end


@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];
    
    placeID = @"";
    self.lblLog.text = @"";
    self.lblID.text = @"";
    self.txtPlaceID.text = @"";
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - IBAction
// スキャンボタン
- (IBAction)scanBtnTapped:(UIButton *)sender {
    
    if (!isScanning) {
        
        isScanning = YES;
        
        // スキャン開始
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
        [sender setTitle:@"STOP SCAN" forState:UIControlStateNormal];
        
        // ログ
        self.lblLog.text = @"Start Scan";
    }
    else {
        
        // スキャン停止
        [self.centralManager stopScan];
        [sender setTitle:@"START SCAN" forState:UIControlStateNormal];
        isScanning = NO;
        
        // ログ
        self.lblLog.text = @"Stop Scan";
    }
}

// Readボタン
- (IBAction)onRead:(id)sender {
    [self read];
}

// Writeボタン
- (IBAction)onWrite:(id)sender {
    [self write];
}

#pragma mark - Read Write
/// 読み込み
- (void) read {
    if (!(self.inputCharacteristic)) {
        // ログ
        self.lblLog.text = @"Input not ready";
        NSLog(@"Input not ready!");
        return;
    }
    
    // 読み込み
    [self.peripheral readValueForCharacteristic:self.inputCharacteristic];
}

/// 書き込み
- (void) write {
    if (!(self.outputCharacteristic)) {
        // ログ
        self.lblLog.text = @"Output not ready";
        NSLog(@"Outoput not ready!");
        return;
    }
    
    NSLog(@"%@", self.txtPlaceID.text);
    
    NSData *data = [self.txtPlaceID.text dataUsingEncoding:NSASCIIStringEncoding];
    
    // 書き込み
    [self.peripheral writeValue:data
              forCharacteristic:self.outputCharacteristic
                           type:CBCharacteristicWriteWithResponse];

    
}

#pragma mark - CBCentralManagerDelegate

// セントラルマネージャの状態が変化すると呼ばれる
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // 特に何もしない
    NSLog(@"centralManagerDidUpdateState:%ld", (long)central.state);
}

// ペリフェラルを発見すると呼ばれる
- (void)   centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)RSSI
{
    NSLog(@"発見したBLEデバイス：%@", peripheral);
    NSLog(@"%d", RSSI.intValue);
    
    // NameがIMBLE0083で近距離なら接続
    if ([peripheral.name hasPrefix:@"IMBLE"] && RSSI.intValue >= -70) {
    
        self.peripheral = peripheral;
        
        // 接続開始
        [self.centralManager connectPeripheral:peripheral
                                       options:nil];
        // ログ
        NSString *log =  @"Start Connect";
        NSLog(@"%@", log);
        self.lblLog.text = log;
        
        // Map ID
        self.lblID.text = peripheral.identifier.UUIDString;
    } else {
        
    }
}

// 接続成功すると呼ばれる
- (void)  centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    // ログ
    NSString *log = @"Success Connect";
    NSLog(@"%@", log);
    self.lblLog.text = log;
    
    peripheral.delegate = self;
    
    // サービス探索開始
    [peripheral discoverServices:nil];
}

// 接続失敗すると呼ばれる
- (void)        centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
    // ログ
    NSString *log = @"Fault Connect";
    NSLog(@"%@", log);
    self.lblLog.text = log;
}

#pragma mark - CBPeripheralDelegate

// サービス発見時に呼ばれる
- (void)     peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *services = peripheral.services;
    NSLog(@"%lu 個のサービスを発見！:%@", (unsigned long)services.count, services);

    
    for (CBService *service in services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"ADA99A7F-888B-4E9F-8080-07DDC240F3CE"]]) {
            // ログ
            NSString *log = @"Search Characteristics";
            NSLog(@"%@", log);
            self.lblLog.text = log;
            
            // キャラクタリスティック探索開始
            [peripheral discoverCharacteristics:nil forService:service];
        }
        
    }
}

// キャラクタリスティック発見時に呼ばれる
- (void)                      peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
    if (error) {
        NSLog(@"エラー:%@", error);
        return;
    }
    
    NSArray *characteristics = service.characteristics;
    NSLog(@"%lu 個のキャラクタリスティックを発見！%@", (unsigned long)characteristics.count, characteristics);
    
    for (CBCharacteristic *characteristic in characteristics) {
        
        // Read専用のキャラクタリスティック
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"ADA99A7F-888B-4E9F-8081-07DDC240F3CE"]]) {
            self.peripheral = peripheral;
            self.inputCharacteristic = characteristic;
//            [peripheral readValueForCharacteristic:characteristic];
        }
        // Write専用のキャラクタリスティック
        else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"ADA99A7F-888B-4E9F-8082-07DDC240F3CE"]]) {
            self.outputCharacteristic = characteristic;
            
            // ログ
            NSString *log = @"Start Write";
            NSLog(@"%@", log);
            self.lblLog.text = log;
            
            [self write];
        }

    }
}

// データ読み出しが完了すると呼ばれる
- (void)                 peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error
{
    if (error) {
        NSLog(@"読み出し失敗...error:%@, characteristic uuid:%@", error, characteristic.UUID);
        return;
    }
    
    NSLog(@"読み出し成功！service uuid:%@, characteristice uuid:%@, value%@",
          characteristic.service.UUID, characteristic.UUID, characteristic.value);
    
        // Read
        NSString *str= [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    
        NSLog(@"read: %@", str);
}

// データ書き込みが完了すると呼ばれる
- (void)                peripheral:(CBPeripheral *)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(NSError *)error
{
    if (error) {
        NSLog(@"Write失敗...error:%@", error);
        return;
    }
    
    // ログ
    NSString *log = @"Success Write";
    NSLog(@"%@", log);
    self.lblLog.text = log;
    
    // 接続切断
    log = @"Disconnect";
    NSLog(@"%@", log);
    self.lblLog.text = log;
    [self.centralManager cancelPeripheralConnection:peripheral];
    
    // TODO: DBへ書き込み
    // UUID, place_id
    
}



@end

