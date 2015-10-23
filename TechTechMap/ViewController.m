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
}
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *outputCharacteristic;
@property (nonatomic, strong) CBCharacteristic *inputCharacteristic;
@end


@implementation ViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                               queue:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


// =============================================================================
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
    
//    if ([peripheral.name hasPrefix:@"konashi"]) {
    
        self.peripheral = peripheral;
        
        // 接続開始
        [self.centralManager connectPeripheral:peripheral
                                       options:nil];
//    }
}

// 接続成功すると呼ばれる
- (void)  centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"接続成功！");
    
    peripheral.delegate = self;
    
    // サービス探索開始
    [peripheral discoverServices:nil];
}

// 接続失敗すると呼ばれる
- (void)        centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error
{
    NSLog(@"接続失敗・・・");
}


// =============================================================================
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
        
        // Readのビットが立っているすべてのキャラクタリスティックに対して読み出し開始
        //        if ((characteristic.properties & CBCharacteristicPropertyRead) != 0) {
        //
        //            [peripheral readValueForCharacteristic:characteristic];
        //        }
        //        else {
        //            NSLog(@"Readプロパティなし:%@", characteristic.UUID);
        //        }
        
        // Read専用のキャラクタリスティックに限定して読み出す場合
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"ADA99A7F-888B-4E9F-8081-07DDC240F3CE"]]) {
            self.peripheral = peripheral;
            self.inputCharacteristic = characteristic;
//            [peripheral readValueForCharacteristic:characteristic];
        }
        // Write専用のキャラクタリスティックに限定して読み込む場合
//        else if (characteristic.properties == CBCharacteristicPropertyWrite
//                 || characteristic.properties == CBCharacteristicPropertyWriteWithoutResponse) {
//            self.outputCharacteristic = characteristic;
//        }
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"ADA99A7F-888B-4E9F-8082-07DDC240F3CE"]]) {
            self.outputCharacteristic = characteristic;
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
    
    // バッテリーレベルのキャラクタリスティックかどうかを判定
//    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A19"]]) {
    
//        unsigned char byte;
//        
//        // 1バイト取り出す
//        [characteristic.value getBytes:&byte length:1];
    
        // Read
        NSString *str= [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    
        NSLog(@"read: %@", str);
    
//        // Read後にWrite
//        if (!(self.outputCharacteristic)) {
//            NSLog(@"Outoput not ready!");
//            return;
//        }
//        NSData *data = [@"world" dataUsingEncoding:NSUTF8StringEncoding];
//        [self.peripheral writeValue:data
//                  forCharacteristic:self.outputCharacteristic
//                               type:CBCharacteristicWriteWithResponse];
////    }
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
    
    NSLog(@"Write成功！");
    
}





// =============================================================================
#pragma mark - IBAction

- (IBAction)scanBtnTapped:(UIButton *)sender {
    
    if (!isScanning) {
        
        isScanning = YES;
        
        // スキャン開始
        [self.centralManager scanForPeripheralsWithServices:nil
                                                    options:nil];
        [sender setTitle:@"STOP SCAN" forState:UIControlStateNormal];
    }
    else {
        
        // スキャン停止
        [self.centralManager stopScan];
        [sender setTitle:@"START SCAN" forState:UIControlStateNormal];
        isScanning = NO;
    }
}

- (IBAction)onRead:(id)sender {
    [self.peripheral readValueForCharacteristic:self.inputCharacteristic];
}

- (IBAction)onWrite:(id)sender {
    // Read後にWrite
    if (!(self.outputCharacteristic)) {
        NSLog(@"Outoput not ready!");
        return;
    }
    NSData *data = [@"world" dataUsingEncoding:NSUTF8StringEncoding];
    [self.peripheral writeValue:data
              forCharacteristic:self.outputCharacteristic
                           type:CBCharacteristicWriteWithResponse];
    //    }

}

@end

