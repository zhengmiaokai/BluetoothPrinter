//
//  MKBluetoothCenter.h
//  BlueTooth
//
//  Created by mikazheng on 2021/10/28.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef NS_ENUM(NSInteger, BTReceiveSource) {
    BTReceiveSourceReadData   = 1,  /// 读取
    BTReceiveSourceNotify     = 2,  /// 订阅
};

@protocol MKBluetoothCenterDelegate <NSObject>

@optional

/* 蓝牙中心状态更新 */
- (void)centralManagerDidUpdateState:(BOOL)isAvailable message:(NSString*)message getStatus:(CBManagerState)state;

- (void)startScan; // 搜索开始
- (void)stopScan; // 搜索结束
- (void)discoverPeripheral:(CBPeripheral*)peripheral; // 发现外部设备

- (void)disconnectPeripheral:(CBPeripheral*)peripheral; // 连接断开
- (void)connectingPeripheral:(CBPeripheral*)peripheral; // 连接
- (void)connectedPeripheral:(CBPeripheral*)peripheral error:(NSError *)error; // 连接完成

- (void)discoverCharacterWriter:(CBCharacteristic *)characteristic; // 找到蓝牙打印特性（包含write属性即可）

- (void)receiveData:(NSData*)data characteristic:(CBCharacteristic *)characteristic source:(BTReceiveSource)source; // 收到数据
- (void)writeResult:(BOOL)success characteristic:(CBCharacteristic *)characteristic; // 写入结果

- (void)receiveData:(NSData*)data descriptor:(CBDescriptor *)descriptor; // 收到数据
- (void)writeResult:(BOOL)success descriptor:(CBDescriptor *)descriptor; // 写入结果

@end


@interface MKBluetoothCenter : NSObject

@property (nonatomic, strong) NSMutableArray *discoverPeripherals; // 发现周边设备

+ (MKBluetoothCenter*)sharedInstance;

- (void)initializeConfigWithDelegate:(id <MKBluetoothCenterDelegate>)delegate;

/* 扫瞄设备（stopScanAfterConnected: 外围蓝牙设备连接后停止扫描）*/
- (void)scanForPeripheralsWithServices:(NSArray *)serviceUUIDs stopScanAfterConnected:(BOOL)stopScanAfterConnected;
- (void)stopScan; // 停止扫瞄

- (void)connectPeripheral:(CBPeripheral*)peripheral serviceUUIDs:(NSArray *)serviceUUIDs characteristicUUIDs:(NSArray *)characteristicUUIDs; // 连接外围设备
- (void)disconnect; // 断开

/* 是否断开 */
- (BOOL)isConnected;
- (BOOL)isConnectedWithIdentify:(NSString *)identify;

#pragma mark - 蓝牙打印 -
- (void)writeData:(NSData *)data; // 写入数据

#pragma mark - 扩展 -
- (NSArray *)currentCharacteristics;
- (NSArray *)currentDescriptors;

/* 写入数据（特性属性包含：CBCharacteristicPropertyWrite 或 CBCharacteristicPropertyWriteWithoutResponse）*/
- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type;

/* 开启特性订阅（特性属性包含：CBCharacteristicPropertyNotify）*/
- (void)setNotifyValue:(BOOL)enabled forCharacteristic:(CBCharacteristic *)characteristic;

/* 读取数据（特性属性包含：CBCharacteristicPropertyRead）*/
- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic;

/* 写入数据（描述）*/
- (void)writeValue:(NSData *)data forDescriptor:(CBDescriptor *)descriptor;

/* 读取数据（描述）*/
- (void)readValueForDescriptor:(CBDescriptor *)descriptor;

@end
