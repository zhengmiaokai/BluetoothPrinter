//
//  MKBTStateModel.m
//  BlueTooth
//
//  Created by mikazheng on 2021/11/3.
//

#import "MKBTStateModel.h"

@implementation MKBTStateModel

+ (MKBTStateModel *)modelWithPeripheral:(CBPeripheral *)peripheral connectState:(BTConnectState)connectState {
    MKBTStateModel* item = [[MKBTStateModel alloc] init];
    item.peripheral = peripheral;
    item.connectState = connectState;
    return item;
}

@end
