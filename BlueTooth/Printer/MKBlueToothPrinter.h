//
//  MKBlueToothPrinter.h
//  BlueTooth
//
//  Created by mikazheng on 2021/11/2.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef NS_ENUM(NSInteger, MKBTConnectErrorType) {
    MKBTConnectErrorTypeNone        = 0,  /// 非异常
    MKBTConnectErrorTypeNoConfig    = 1,  /// 未配置蓝牙
    MKBTConnectErrorTypeTimeOut     = 2,  /// 连接超时
};

typedef void(^MKScanCallBack)(CBPeripheral* peripheral, NSArray* peripherals);
typedef void(^MKConnectCallBack)(CBPeripheral* peripheral, MKBTConnectErrorType connectErrorType);

@interface MKBlueToothPrinter : NSObject

/// 连接超时设置（未找到设备，连接异常），默认为 8s
@property (nonatomic, assign)  NSInteger timeout;

/// 非主动断开时，是否自动重连，默认为 NO
@property (nonatomic, assign) BOOL isReConnect;

/// 当匹配到之前连接的设备后，是否自动连接，默认为 YES
@property (nonatomic, assign) BOOL isAutoConnect;

+ (MKBlueToothPrinter *)sharedInstance;

/// 扫描到外围设备回调
- (void)addScanCallBack:(MKScanCallBack)scanCallBack forKey:(NSString *)key;
- (void)removeScanCallBackForKey:(NSString *)key;

/// 设备连接状态变更回调
- (void)addConnectCallBack:(MKConnectCallBack)connectCallBack forKey:(NSString *)key;
- (void)removeConnectCallBackForKey:(NSString *)key;

/// 扫描外围设备
- (void)scanForPeripherals;

/// 是否已连接外围设备
- (BOOL)isConnected;

/// 获取已发现的外围设备列表
- (NSArray <CBPeripheral*>*)discoverPeripherals;

/// 断开当前已连接的蓝牙设备
- (void)disconnectPeripheral;

/// 连接外围蓝牙设备
- (void)connectPeripheral:(CBPeripheral*)periphera;

/// 打印订单小票
- (void)printOrderWithData:(NSData *)data printCallBack:(void(^)(BOOL success, MKBTConnectErrorType connectErrorType))printCallBack;

@end
