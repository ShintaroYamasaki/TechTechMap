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
    
    NSMutableArray *sentMaps;
}
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
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
    sentMaps = [NSMutableArray array];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/// ログ表示
- (void) showLog: (NSString *) log {
    self.lblLog.text = log;
    NSLog(@"%@", log);

}

#pragma mark - IBAction
// スキャンボタン
- (IBAction)scanBtnTapped:(UIButton *)sender {
    
    if (!isScanning) {
        
        isScanning = YES;
        
        // スキャン開始
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
        
        [sender setTitle:@"Stop" forState:UIControlStateNormal];
        
        // ログ
        [self showLog:@"Start Scan"];
    }
    else {
        
        // スキャン停止
        [self.centralManager stopScan];
        
        [sender setTitle:@"Start" forState:UIControlStateNormal];
        isScanning = NO;
        
        // ログ
        [self showLog:@"Stop Scan"];
    }
}

// リセット
- (IBAction)onReset:(id)sender {
    sentMaps = [NSMutableArray array];
}

#pragma mark - Read Write
/// 読み込み
//- (void) read: (CBCharacteristic *) characteristic Peripheral: (CBPeripheral *) peripheral{
//    if (!(characteristic)) {
//        // ログ
//        [self showLog:@"Input not ready"];
//        
//        return;
//    }
//    
//    // 読み込み
//    [peripheral readValueForCharacteristic:characteristic];
//}

/// 書き込み
- (void) write: (CBCharacteristic *) characteristic Peripheral: (CBPeripheral *) peripheral {
    if (!(characteristic)) {
        // ログ
        [self showLog:@"Outoput not ready!"];
        
        return;
    }
    
    NSLog(@"%@", self.txtPlaceID.text);
    
    NSData *data = [self.txtPlaceID.text dataUsingEncoding:NSASCIIStringEncoding];
    
    // 書き込み
    [peripheral writeValue:data
              forCharacteristic:characteristic
                           type:CBCharacteristicWriteWithResponse];
}

#pragma mark - CBCentralManagerDelegate
// セントラルマネージャの状態が変化すると呼ばれる
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    // 特に何もしない
    NSLog(@"centralManagerDidUpdateState:%ld", (long)central.state);
}

// ペリフェラルを発見すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"発見したBLEデバイス：%@", peripheral);
    NSLog(@"%d", RSSI.intValue);
    
    // NameがIMBLE0083で近距離なら接続
//    if ([peripheral.name hasPrefix:@"IMBLE"] && RSSI.intValue >= -70) {
        // すでにコマンドを送ったMapであれば、接続しない
        for (NSString *mapid in sentMaps) {
            if ([mapid isEqual:peripheral.identifier.UUIDString]) {
                return;
            }
        }
        self.peripheral = peripheral;
    
        // Map ID
        self.lblID.text = peripheral.identifier.UUIDString;
    
//        [self.centralManager stopScan];
    
        // 接続開始
        [self.centralManager connectPeripheral:peripheral
                                       options:nil];
    
        // ログ
        [self showLog:@"Start Connect"];

//    }
}

/// 接続成功すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // ログ
    [self showLog:@"Success Connect"];
    
    peripheral.delegate = self;
    
    // サービス探索開始
    [peripheral discoverServices:nil];
}

/// 切断成功するとよばれる
- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // スキャン開始
//    [self.centralManager scanForPeripheralsWithServices:nil
//                                                options:nil];
    
    [self showLog:@"Disconnect"];
}

// 接続失敗すると呼ばれる
- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {

    // ログ
    [self showLog:@"Fault Connect"];

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
        if ([service.UUID isEqual:[CBUUID UUIDWithString:kServiceUUID]]) {
            // ログ
            [self showLog:@"Search Characteristics"];
            
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
        
        // Write専用のキャラクタリスティック
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kWriteUUID]]) {
            // ログ
            [self showLog:@"Start Write"];
            
            [self write:characteristic Peripheral:peripheral];
        }

    }
}

// データ読み出しが完了すると呼ばれる
//- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    if (error) {
//        NSLog(@"読み出し失敗...error:%@, characteristic uuid:%@", error, characteristic.UUID);
//        return;
//    }
//    
//    NSLog(@"読み出し成功！service uuid:%@, characteristice uuid:%@, value%@",
//          characteristic.service.UUID, characteristic.UUID, characteristic.value);
//    
//        // Read
//        NSString *str= [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
//    
//        NSLog(@"read: %@", str);
//}

// データ書き込みが完了すると呼ばれる
- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Write失敗...error:%@", error);
        return;
    }
    
    // ログ
    [self showLog:@"Success Write"];
    
    [self.centralManager scanForPeripheralsWithServices:nil
                                                     options:nil];
    
    // 接続切断
    [self.centralManager cancelPeripheralConnection:peripheral];
    
    
    // TODO: DBへ書き込み
    // UUID, place_id
    
    
    // 送信済みArrayに追加
    [sentMaps addObject:peripheral.identifier.UUIDString];
    
    // スキャン開始
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:nil];

}



@end

