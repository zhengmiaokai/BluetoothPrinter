//
//  MKBlueToothPrinter.m
//  BlueTooth
//
//  Created by mikazheng on 2021/11/2.
//

#import "MKBlueToothPrinter.h"
#import "MKBluetoothManager.h"

/// 蓝牙打印机通用服务
#define kServiceUUID1         [CBUUID UUIDWithString:@"49535343-FE7D-4AE5-8FA9-9FAFD205E455"]
#define kServiceUUID2         [CBUUID UUIDWithString:@"E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"]

#define kBTPeripheralIdentify @"BTPeripheralIdentify"

@interface MKBlueToothPrinter () <MKBluetoothManagerDelegate> {
    BOOL _isManualDisconnect; // 手动断开
}

@property (nonatomic, strong) id data;

@property (nonatomic, copy) void(^printCallBack)(BOOL success, MKBTConnectErrorType connectErrorType);

@property (nonatomic, strong) NSTimer* connectTimer;
@property (nonatomic, assign) NSInteger connectInterval;

@property (nonatomic, strong) NSMutableDictionary* scanBlocks;
@property (nonatomic, strong) NSMutableDictionary* connectBlocks;

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
        self.timeout = 8;
        self.isReConnect = NO;
        self.isAutoConnect = YES;
        _isManualDisconnect = NO;
        
        self.scanBlocks = [NSMutableDictionary dictionary];
        self.connectBlocks = [NSMutableDictionary dictionary];
        
        [[MKBluetoothManager sharedInstance] initializeConfigWithDelegate:self];
    }
    return self;
}

/// 扫描到外围设备
- (void)addScanCallBack:(MKScanCallBack)scanCallBack forKey:(NSString *)key {
    if (scanCallBack && key) {
        [_scanBlocks setObject:[scanCallBack copy] forKey:key];
    }
}

- (void)removeScanCallBackForKey:(NSString *)key {
    if (key) {
        [_scanBlocks removeObjectForKey:key];
    }
}

/// 设备连接状态变更
- (void)addConnectCallBack:(MKConnectCallBack)connectCallBack forKey:(NSString *)key {
    if (connectCallBack && key) {
        [_connectBlocks setObject:[connectCallBack copy] forKey:key];
    }
}

- (void)removeConnectCallBackForKey:(NSString *)key {
    if (key) {
        [_connectBlocks removeObjectForKey:key];
    }
}

- (void)scanForPeripherals {
    [[MKBluetoothManager sharedInstance] scanForPeripheralsWithServices:@[kServiceUUID1, kServiceUUID2] stopScanAfterConnected:NO];
}

- (void)connectPeripheral:(CBPeripheral*)peripheral {
    if ([[MKBluetoothManager sharedInstance] isConnected]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kBTPeripheralIdentify];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[MKBluetoothManager sharedInstance] disconnect];
        _isManualDisconnect = YES;
    } else {
        [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
        _isManualDisconnect = NO;
        
        [[_connectBlocks allValues] enumerateObjectsUsingBlock:^(MKConnectCallBack  _Nonnull connectCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
            connectCallBack(peripheral, NO);
        }];
        /// 处理连接超时
        [self createConnectTimer];
    }
}

- (void)printOrderWithData:(NSData *)data printCallBack:(void (^)(BOOL success, MKBTConnectErrorType connectErrorType))printCallBack {
    NSString* UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:kBTPeripheralIdentify];
    if (UUIDString.length == 0) {
        NSLog(@"未配置打印机");
        /// 未配置蓝牙回调
        [[self.connectBlocks allValues] enumerateObjectsUsingBlock:^(MKConnectCallBack  _Nonnull connectCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
            connectCallBack(nil, MKBTConnectErrorTypeNoConfig);
        }];
        
        /// 打印回调
        if (printCallBack) {
            printCallBack(NO, MKBTConnectErrorTypeNoConfig);
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
                [self scanForPeripherals];
            }
            /// 处理连接超时
            [self createConnectTimer];
        }
    }
}

- (void)createConnectTimer {
    __weak typeof(self) wSelf = self;
    self.connectTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(wSelf) sSelf = wSelf;
        sSelf.connectInterval ++;
        if (sSelf.timeout && (sSelf.connectInterval >= sSelf.timeout)) {
            [sSelf destroyConnectTimer];
            sSelf.data = nil;
            
            /// 连接超时回调
            [[sSelf.connectBlocks allValues] enumerateObjectsUsingBlock:^(MKConnectCallBack  _Nonnull connectCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
                connectCallBack(nil, MKBTConnectErrorTypeTimeOut);
            }];
            
            /// 打印回调
            if (sSelf.printCallBack) {
                sSelf.printCallBack(NO, MKBTConnectErrorTypeTimeOut);
                sSelf.printCallBack = nil;
            }
            
            /// 取消当前连接
            [[MKBluetoothManager sharedInstance] disconnect];
        }
    }];
}

- (void)destroyConnectTimer {
    self.connectInterval = 0;
    if (self.connectTimer) {
        [self.connectTimer invalidate];
        self.connectTimer = nil;
    }
}

#pragma mark - BluetoothMessageDelegate -
- (void)centralManagerDidUpdateState:(BOOL)isAvailable message:(NSString *)message getStatus:(CBManagerState)state {
    if (isAvailable) {
        [self scanForPeripherals];
    }
}

- (void)discoverPeripheral:(CBPeripheral *)peripheral {
    NSString* UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:kBTPeripheralIdentify];
    if (_isAutoConnect && (UUIDString.length > 0)) {
        if ([peripheral.identifier.UUIDString isEqualToString:UUIDString]) {
            [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
        }
    }
    
    [[_scanBlocks allValues] enumerateObjectsUsingBlock:^(MKScanCallBack  _Nonnull scanCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
        scanCallBack(peripheral, [[MKBluetoothManager sharedInstance].discoverPeripherals copy]);
    }];
}

- (void)connectedPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (!error) {
        [[NSUserDefaults standardUserDefaults] setObject:peripheral.identifier.UUIDString forKey:kBTPeripheralIdentify];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [[_connectBlocks allValues] enumerateObjectsUsingBlock:^(MKConnectCallBack  _Nonnull connectCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
        connectCallBack(peripheral, NO);
    }];
    
    [self destroyConnectTimer];
}

- (void)disconnectPeripheral:(CBPeripheral *)peripheral {
    [[_connectBlocks allValues] enumerateObjectsUsingBlock:^(MKConnectCallBack  _Nonnull connectCallBack, NSUInteger idx, BOOL * _Nonnull stop) {
        connectCallBack(peripheral, NO);
    }];
    
    /// 非主动断开，且设置了自动重连，触发重连逻辑
    if (!_isManualDisconnect && _isReConnect) {
        [[MKBluetoothManager sharedInstance] connectPeripheral:peripheral serviceUUIDs:nil characteristicUUIDs:nil];
    }
    [self destroyConnectTimer];
}

- (void)discoverCharacterWriter:(CBCharacteristic *)characteristic {
    if (self.data) {
        [[MKBluetoothManager sharedInstance] writeData:self.data];
        self.data = nil;
    }
}

- (void)writeResult:(BOOL)success characteristic:(CBCharacteristic *)characteristic {
    if (_printCallBack) {
        _printCallBack(success, MKBTConnectErrorTypeNone);
        self.printCallBack = nil;
    }
}

@end
