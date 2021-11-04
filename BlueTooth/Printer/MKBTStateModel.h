//
//  MKBTStateModel.h
//  BlueTooth
//
//  Created by mikazheng on 2021/11/3.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

typedef NS_ENUM(NSInteger, BTConnectState) {
    BTConnectStateDisconnect    = 0,  /// 已断开
    BTConnectStateConnecting    = 1,  /// 链接中
    BTConnectStateConnected     = 2,  /// 已链接
};

@interface MKBTStateModel : NSObject

@property (nonatomic, assign) BTConnectState connectState;
@property (nonatomic, strong) CBPeripheral* peripheral;

+ (MKBTStateModel *)modelWithPeripheral:(CBPeripheral *)peripheral connectState:(BTConnectState)connectState;

@end
