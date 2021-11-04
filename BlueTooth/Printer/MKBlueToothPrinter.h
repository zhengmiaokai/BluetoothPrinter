//
//  MKBlueToothPrinter.h
//  BlueTooth
//
//  Created by mikazheng on 2021/11/2.
//

#import <Foundation/Foundation.h>
#import "MKBTStateModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MKBlueToothPrinter : NSObject

/// 非主动断开时，是否自动重连，默认为 NO
@property (nonatomic, assign) BOOL isReConnect;

/// 当匹配到之前连接的设备后，是否自动连接，默认为 YES
@property (nonatomic, assign) BOOL isAutoConnect;

/// 扫描到外围设备
@property (nonatomic, copy) void(^scanCallBack)(CBPeripheral* peripheral, NSArray* peripherals);

/// 设备连接状态变更
@property (nonatomic, copy) void(^connectCallBack)(MKBTStateModel* stateItem);

+ (MKBlueToothPrinter *)sharedInstance;

/// 初始化蓝牙中心配置
- (void)initializeBlueTooth;

/// 连接外围蓝牙设备
- (void)connectPeripheral:(CBPeripheral*)periphera;

/// 打印订单小票
- (void)printOrderWithData:(NSData *)data printCallBack:(void(^)(BOOL success))printCallBack;

@end

NS_ASSUME_NONNULL_END
