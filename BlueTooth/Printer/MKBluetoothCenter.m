//
//  MKBluetoothCenter.m
//  BlueTooth
//
//  Created by mikazheng on 2021/10/28.
//

#import "MKBluetoothCenter.h"

@interface MKBluetoothCenter () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, weak) id <MKBluetoothCenterDelegate> delegate;

@property (nonatomic, strong) CBCentralManager*  cbCentralMgr;
@property (nonatomic, strong) CBPeripheral*      cbPeripheral;

/// 供蓝牙打印使用
@property (nonatomic, strong) CBCharacteristic*   cbCharacterWriter;

@property (nonatomic, strong) NSMutableArray* services;
@property (nonatomic, strong) NSMutableArray* characteristics;
@property (nonatomic, strong) NSMutableArray* descriptors;

@property (nonatomic, strong) NSArray* serviceUUIDs;
@property (nonatomic, strong) NSArray* characteristicUUIDs;

@property (nonatomic, assign) BOOL stopScanAfterConnected;

@property (nonatomic, assign) NSInteger writeCount;
@property (nonatomic, assign) NSInteger didWriteCount;

@end

@implementation MKBluetoothCenter

+ (MKBluetoothCenter *)sharedInstance {
    static MKBluetoothCenter* bluetoothMgr = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bluetoothMgr = [[self alloc] init];
    });
    return bluetoothMgr;
}

- (void)initializeConfigWithDelegate:(id <MKBluetoothCenterDelegate>)delegate {
    self.delegate = delegate;
    
    /* 蓝牙没打开时，alert弹窗提示 */
    NSDictionary *options = @{CBCentralManagerOptionShowPowerAlertKey: @(YES)};
    self.cbCentralMgr = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:options];
    
    self.discoverPeripherals = [NSMutableArray array];
    
    self.services = [NSMutableArray array];
    self.characteristics = [NSMutableArray array];
    self.descriptors = [NSMutableArray array];
}

- (void)_destroyCache {
    self.cbCharacterWriter = nil;
    [_services removeAllObjects];
    [_characteristics removeAllObjects];
    [_descriptors removeAllObjects];
}

- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs stopScanAfterConnected:(BOOL)stopScanAfterConnected {
    self.stopScanAfterConnected = stopScanAfterConnected;
    [self stopScan];
    
    [_discoverPeripherals removeAllObjects];
    
    /* CBCentralManagerScanOptionAllowDuplicatesKey: NO 不重复扫描，设置为YES是在前台运行会一直扫描，除非主动stopScan */
    [self.cbCentralMgr scanForPeripheralsWithServices:serviceUUIDs options: @{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
    
    if (_delegate && [_delegate respondsToSelector:@selector(startScan)]) {
        [_delegate startScan];
    }
}

- (void)stopScan {
    if (self.cbCentralMgr.isScanning) {
        [self.cbCentralMgr stopScan];
        
        if (_delegate && [_delegate respondsToSelector:@selector(stopScan)]) {
            [_delegate stopScan];
        }
    }
}

- (void)connectPeripheral:(CBPeripheral*)peripheral serviceUUIDs:(NSArray *)serviceUUIDs characteristicUUIDs:(NSArray *)characteristicUUIDs {
    [self _destroyCache];
    
    self.serviceUUIDs = serviceUUIDs;
    self.characteristicUUIDs = characteristicUUIDs;
    
    if (peripheral) {
        self.cbPeripheral = peripheral;
        self.cbPeripheral.delegate = self;
    } else {
        if (!self.cbPeripheral) {
            NSLog(@"peripheral can not be nil !!!");
            return;
        }
    }
    
    /* options配置
    CBConnectPeripheralOptionNotifyOnConnectionKey 在程序被挂起时，连接成功显示Alert提醒框
    CBConnectPeripheralOptionNotifyOnDisconnectionKey 在程序被挂起时，断开连接显示Alert提醒框
    CBConnectPeripheralOptionNotifyOnNotificationKey 在程序被挂起时，显示所有的提醒消息
     */
    [self.cbCentralMgr connectPeripheral:self.cbPeripheral options:nil];
    
    if (_delegate && [_delegate respondsToSelector:@selector(connectingPeripheral:)]) {
        [_delegate connectingPeripheral:peripheral];
    }
}

- (void)disconnect {
    if (self.cbPeripheral && self.cbPeripheral.state == CBPeripheralStateConnected) {
        self.cbPeripheral.delegate = self;
        [self.cbCentralMgr cancelPeripheralConnection:self.cbPeripheral];
        self.cbPeripheral = nil;
    }
}

- (BOOL)isConnected {
    return (self.cbPeripheral.state == CBPeripheralStateConnected ? YES : NO);
}

#pragma mark - 蓝牙打印 -
- (void)writeData:(NSData *)data {
    [self writeValue:data forCharacteristic:self.cbCharacterWriter type:CBCharacteristicWriteWithResponse];
}

#pragma mark - 扩展 -
- (NSArray *)currentCharacteristics {
    return [_characteristics copy];
}

- (NSArray *)currentDescriptors {
    return [_descriptors copy];
}

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type {
    if (!characteristic) {
        NSLog(@"characteristic can not be nil !!!");
        if ([self isConnected]) {
            [_cbPeripheral discoverServices:_serviceUUIDs];
        }
        
        if (_delegate && [_delegate respondsToSelector:@selector(writeResult:characteristic:)]) {
            [_delegate writeResult:NO characteristic:nil];
        }
    } else {
        _writeCount = 0;
        _didWriteCount = 0;
        
        /* iOS9之后提供了查询蓝牙写入最大长度，目前测试的蓝牙设备，data长度超过maxLength也可以正常输出 */
        NSInteger maxLength = [_cbPeripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];
        
        /// 防止个别设备出现传输异常，数据大于maxLength时使用分节传输
        if ((maxLength <= 0) || (maxLength >= data.length)) {
            [self.cbPeripheral writeValue:data forCharacteristic:characteristic type:type];
            _writeCount++;
        } else {
            NSInteger location = 0;
            /// 先取出maxLength大小的subData逐个写入
            for (location = 0; location < data.length - maxLength; location += maxLength) {
                NSData *subData = [data subdataWithRange:NSMakeRange(location, maxLength)];
                [_cbPeripheral writeValue:subData forCharacteristic:characteristic type:type];
                _writeCount++;
            }
            /// 再取出小于maxLength的lastData写入
            NSData *lastData = [data subdataWithRange:NSMakeRange(location, data.length - location)];
            if (lastData) {
                [_cbPeripheral writeValue:lastData forCharacteristic:characteristic type:type];
                _writeCount++;
            }
        }
    }
}

- (void)setNotifyValue:(BOOL)enabled forCharacteristic:(CBCharacteristic *)characteristic {
    [self.cbPeripheral setNotifyValue:enabled forCharacteristic:characteristic];
}

- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic {
    [self.cbPeripheral readValueForCharacteristic:characteristic];
}

- (void)writeValue:(NSData *)data forDescriptor:(CBDescriptor *)descriptor {
    [self.cbPeripheral writeValue:data forDescriptor:descriptor];
}

- (void)readValueForDescriptor:(CBDescriptor *)descriptor {
    [self.cbPeripheral readValueForDescriptor:descriptor];
}

#pragma mark - CBCentralManagerDelegate -
/// 收到了一个周围的蓝牙发来的广播信息
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral.name) {
        __block BOOL exist = NO;
        [_discoverPeripherals enumerateObjectsUsingBlock:^(CBPeripheral*  _Nonnull tmpPeripheral, NSUInteger index, BOOL * _Nonnull stop) {
            if ([tmpPeripheral.identifier isEqual:peripheral.identifier]) {
                exist = YES;
                *stop = YES;
            }
        }];
        
        if (exist == NO) {
            [_discoverPeripherals addObject:peripheral];
            
            if (_delegate && [_delegate respondsToSelector:@selector(discoverPeripheral:)]) {
                [_delegate discoverPeripheral:peripheral];
            }
        }
    }
}

/// 连接上当前蓝牙设备
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (_stopScanAfterConnected) {
        [self stopScan];
    }
    
    [self.cbPeripheral discoverServices:_serviceUUIDs];
    
    if (_delegate && [_delegate respondsToSelector:@selector(connectedPeripheral:error:)]) {
        [_delegate connectedPeripheral:peripheral error:nil];
    }
}
/// 当前设备蓝牙断开
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (_delegate && [_delegate respondsToSelector:@selector(disconnectPeripheral:)]) {
        [_delegate disconnectPeripheral:peripheral];
    }
    [self _destroyCache];
}

/// 蓝牙连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (_delegate && [_delegate respondsToSelector:@selector(connectedPeripheral:error:)]) {
        [_delegate connectedPeripheral:peripheral error:error];
    }
}

/// 蓝牙中心状态更新
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSMutableString* updateInfo=[NSMutableString stringWithString:@"UpdateState:"];
    BOOL isAvailable = NO;
    switch (self.cbCentralMgr.state) {
        case CBManagerStateUnknown:
            [updateInfo appendString:@"Unknown\n"];
            break;
        case CBManagerStateUnsupported:
            [updateInfo appendString:@"Unsupported\n"];
            break;
        case CBManagerStateUnauthorized:
            [updateInfo appendString:@"Unauthorized\n"];
            break;
        case CBManagerStateResetting:
            [updateInfo appendString:@"Resetting\n"];
            break;
        case CBManagerStatePoweredOff:
            [updateInfo appendString:@"PoweredOff\n"];
            if (self.cbPeripheral){
                [self.cbCentralMgr cancelPeripheralConnection:self.cbPeripheral];
            }
            break;
        case CBManagerStatePoweredOn:
            [updateInfo appendString:@"PoweredOn\n"];
            isAvailable = YES;
            break;
        default:
            [updateInfo appendString:@"none\n"];
            break;
    }
    NSLog(@"%@", updateInfo);
    if (_delegate && [_delegate respondsToSelector:@selector(centralManagerDidUpdateState:message:getStatus:)]) {
        [_delegate centralManagerDidUpdateState:isAvailable message:updateInfo getStatus:self.cbCentralMgr.state];
    }
}

#pragma mark - CBPeripheralDelegate -
/// 查询蓝牙服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"DidDiscoverServicesFailed: %@", error.localizedDescription);
        [peripheral discoverServices:_serviceUUIDs];
    } else {
        for (CBService *service in peripheral.services) {
            if (service.UUID.UUIDString.length == 36) {
                [_services addObject:service];
                [peripheral discoverCharacteristics:_characteristicUUIDs forService:service];
            }
        }
    }
}

/// 查询服务所带的特征值
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"DidDiscoverCharacteristicsFailed: %@", error.localizedDescription);
        [peripheral discoverCharacteristics:_characteristicUUIDs forService:service];
    } else {
        for (CBCharacteristic *characteristic in [service characteristics]) {
            if (characteristic.UUID.UUIDString.length == 36) {
                if (!self.cbCharacterWriter && (characteristic.properties & CBCharacteristicPropertyWrite)) {
                    self.cbCharacterWriter = characteristic;
                    
                    if (_delegate && [_delegate respondsToSelector:@selector(discoverCharacterWriter:)]) {
                        [_delegate discoverCharacterWriter:characteristic];
                    }
                }
                [_characteristics addObject:characteristic];
                [peripheral discoverDescriptorsForCharacteristic:characteristic];
            }
        }
    }
}

 /// 向蓝牙发送数据后的回调（Characteristic）
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
         NSLog(@"DidWriteValueForCharacteristic");
    } else{
        NSLog(@"DidWriteValueForCharacteristicFail: %@", [error description]);
    }
    
    _didWriteCount++;
    if (_writeCount == _didWriteCount) {
        if (_delegate && [_delegate respondsToSelector:@selector(writeResult:characteristic:)]) {
            [_delegate writeResult:!error characteristic:characteristic];
        }
    }
}

/// 处理蓝牙发过来的数据（Characteristic）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
        NSData* data = characteristic.value;
        if (_delegate && [_delegate respondsToSelector:@selector(receiveData:characteristic:source:)]) {
            [_delegate receiveData:data characteristic:characteristic source:BTReceiveSourceReadData];
        }
        NSLog(@"DidUpdateValueForCharacteristic: %@", data);
    } else {
        NSLog(@"DidUpdateValueForCharacteristicFail: %@", [error description]);
    }
}

/// 已订阅特性的value更新回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (!error) {
        NSData* data = characteristic.value;
        if (_delegate && [_delegate respondsToSelector:@selector(receiveData:characteristic:source:)]) {
            [_delegate receiveData:data characteristic:characteristic source:BTReceiveSourceNotify];
        }
        NSLog(@"didUpdateNotificationStateForCharacteristic: %@", data);
    } else {
        NSLog(@"DidUpdateNotificationStateForCharacteristicFail: %@", [error description]);
    }
}

/// 查询特性所带的描述
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"DidDiscoverDescriptorsFailed: %@", error.localizedDescription);
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
    } else {
        for (CBDescriptor* descriptor in characteristic.descriptors) {
            if (descriptor.UUID.UUIDString.length == 36) {
                [_descriptors addObject:descriptor];
            }
        }
    }
}

/// 向蓝牙发送数据后的回调（Descriptor）
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    if (!error) {
         NSLog(@"DidWriteValueForDescriptor");
    } else {
        NSLog(@"DidWriteValueForDescriptorFail: %@", [error description]);
    }
    
    if (_delegate && [_delegate respondsToSelector:@selector(writeResult:descriptor:)]) {
        [_delegate writeResult:!error descriptor:descriptor];
    }
}

/// 向蓝牙发送数据后的回调（Descriptor)
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    if (!error) {
        NSData* data = descriptor.value;
        if (_delegate && [_delegate respondsToSelector:@selector(receiveData:descriptor:)]) {
            [_delegate receiveData:data descriptor:descriptor];
        }
        NSLog(@"DidUpdateValueForDescriptor: %@", data);
    } else {
        NSLog(@"DidUpdateValueForDescriptorFail: %@", [error description]);
    }
}

@end
