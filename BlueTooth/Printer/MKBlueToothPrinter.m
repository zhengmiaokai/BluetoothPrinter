//
//  MKBlueToothPrinter.m
//  BlueTooth
//
//  Created by mikazheng on 2021/11/2.
//

#import "MKBlueToothPrinter.h"
#import "MKBluetoothManager.h"

@interface MKBlueToothPrinter () <MKBluetoothManagerDelegate> {
    BOOL _isManualDisconnect; // 手动断开
}

@property (nonatomic, strong) id data;

@property (nonatomic, copy) void(^printCallBack)(BOOL success);

@end

@implementation MKBlueToothPrinter

+ (MKBlueToothPrinter *)sharedInstance {
    static MKBlueToothPrinter* bluetoothPrinter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bluetoothPrinter = [[self alloc] init];
    });
    return bluetoothPrinter;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isReConnect = NO;
        self.isAutoConnect = YES;
        _isManualDisconnect = NO;
    }
    return self;
}

- (void)initializeBlueTooth {
    [[MKBluetoothManager sharedInstance] initializeConfigWithDelegate:self];
}

- (void)connectPeripheral:(CBPeripheral*)peripheral {
    if ([[MKBluetoothManager sharedInstance] isConnected]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BTPeripheralIdentify"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[MKBluetoothManager sharedInstance] disconnect];
        _isManualDisconnect = YES;
    } else {
        [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
        _isManualDisconnect = NO;
        
        if (_connectCallBack) {
            MKBTStateModel* stateItem = [MKBTStateModel modelWithPeripheral:peripheral connectState:BTConnectStateConnecting];
            _connectCallBack(stateItem);
        }
    }
}

- (void)printOrderWithData:(NSData *)data printCallBack:(nonnull void (^)(BOOL))printCallBack {
    NSString* UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:@"BTPeripheralIdentify"];
    if (UUIDString.length == 0) {
        NSLog(@"未配置打印机");
        if (printCallBack) {
            printCallBack(NO);
        }
    } else {
        self.printCallBack = printCallBack;
        /// 已连接
        if ([[MKBluetoothManager sharedInstance] isConnected]) {
             [[MKBluetoothManager sharedInstance] writeData:data];
        } else {
            self.data = data;
            
           __block BOOL isExist = NO;
            [[MKBluetoothManager sharedInstance].discoverPeripherals enumerateObjectsUsingBlock:^(CBPeripheral*  _Nonnull peripheral, NSUInteger index, BOOL * _Nonnull stop) {
                /// 已扫描列表已包含记录的设备
                if ([peripheral.identifier.UUIDString isEqualToString:UUIDString]) {
                    isExist = YES;
                    [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
                    *stop = YES;
                }
            }];
            
            /// 已扫描列表未包含记录的设备，重新扫描
            if (!isExist) {
                [[MKBluetoothManager sharedInstance] scanForPeripheralsWithServices:nil stopScanAfterConnected:NO];
            }
        }
    }
}


#pragma mark - BluetoothMessageDelegate -
- (void)centralManagerDidUpdateState:(BOOL)isAvailable message:(NSString *)message getStatus:(CBManagerState)state {
    if (isAvailable) {
        [[MKBluetoothManager sharedInstance] scanForPeripheralsWithServices:nil stopScanAfterConnected:NO];
    }
}

- (void)discoverPeripheral:(CBPeripheral *)peripheral {
    NSString* UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:@"BTPeripheralIdentify"];
    if (_isAutoConnect && (UUIDString.length > 0)) {
        if ([peripheral.identifier.UUIDString isEqualToString:UUIDString]) {
            [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
        }
    }
    
    if (_scanCallBack) {
        _scanCallBack(peripheral, [[MKBluetoothManager sharedInstance].discoverPeripherals copy]);
    }
}

- (void)connectedPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (!error) {
        [[NSUserDefaults standardUserDefaults] setObject:peripheral.identifier.UUIDString forKey:@"BTPeripheralIdentify"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if (_connectCallBack) {
        MKBTStateModel* stateItem = [MKBTStateModel modelWithPeripheral:peripheral connectState:(error ? BTConnectStateDisconnect : BTConnectStateConnected)];
        _connectCallBack(stateItem);
    }
}

- (void)disconnectPeripheral:(CBPeripheral *)peripheral {
    if (_connectCallBack) {
        MKBTStateModel* stateItem = [MKBTStateModel modelWithPeripheral:peripheral connectState:BTConnectStateDisconnect];
        _connectCallBack(stateItem);
    }
    
    /// 非主动断开，且设置了自动重连，触发重连逻辑
    if (!_isManualDisconnect && _isReConnect) {
        [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
    }
}

- (void)discoverCharacterWriter:(CBCharacteristic *)characteristic {
    if (self.data) {
        [[MKBluetoothManager sharedInstance] writeData:self.data];
        self.data = nil;
    }
}

- (void)writeResult:(BOOL)success characteristic:(CBCharacteristic *)characteristic {
    if (_printCallBack) {
        _printCallBack(success);
    }
}

@end
