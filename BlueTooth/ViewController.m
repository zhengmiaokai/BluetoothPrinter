//
//  ViewController.m
//  BlueTooth
//
//  Created by mikazheng on 2021/10/28.
//

#import "ViewController.h"
#import "MKBlueToothPrinter.h"
#import "PrinterFormat/HLPrinter.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView* tableView;

@property (nonatomic, strong) CBPeripheral* peripheral;
@property (nonatomic, copy) NSArray* peripherals;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.view addSubview:self.tableView];
    [self.view addSubview:[self button]];
    
    NSString* key = [NSString stringWithFormat:@"to%@",NSStringFromClass(self.class)];
    __weak typeof(self) weakSelf = self;
    [[MKBlueToothPrinter sharedInstance] addScanCallBack:^(CBPeripheral *peripheral, NSArray *peripherals) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.peripherals = peripherals;
        [strongSelf.tableView reloadData];
    } forKey:key];
    
    [[MKBlueToothPrinter sharedInstance] addConnectCallBack:^(CBPeripheral *peripheral, MKBTConnectErrorType connectErrorType) {
        if (connectErrorType == MKBTConnectErrorTypeNone) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.peripheral = peripheral;
            [strongSelf.tableView reloadData];
        } else if (connectErrorType == MKBTConnectErrorTypeTimeOut) {
            NSLog(@"蓝牙链接超时");
        } else if (connectErrorType == MKBTConnectErrorTypeNoConfig) {
            NSLog(@"蓝牙未配置");
        }
    } forKey:key];
    
    [[MKBlueToothPrinter sharedInstance] scanForPeripherals];
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

- (UIButton *)button {
    UIButton* btn = [[UIButton alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 60, self.view.bounds.size.width, 60)];
    [btn setTitle:@"打印" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor blueColor]];
    [btn addTarget:self action:@selector(print:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)print:(UIButton *)btn {
    HLPrinter* printer = [self getPrinter];
    [[MKBlueToothPrinter sharedInstance] printOrderWithData:[printer getFinalData] printCallBack:^(BOOL success, MKBTConnectErrorType connectErrorType) {
        if (success) {
            NSLog(@"订单已经打印！！！");
        }
    }];
}

- (HLPrinter *)getPrinter {
    HLPrinter *printer = [[HLPrinter alloc] init];
    
    NSString *title = @"测试电商";
    NSString *str1 = @"测试电商服务中心(销售单)";
    [printer appendText:title alignment:HLTextAlignmentCenter fontSize:HLFontSizeTitleBig];
    [printer appendText:str1 alignment:HLTextAlignmentCenter];
    
    /* 暂时屏蔽，以免消耗太多打印纸
    // 条形码
    [printer appendBarCodeWithInfo:@"123456789012"];
    [printer appendSeperatorLine];
    
    [printer appendTitle:@"时间:" value:@"2016-04-27 10:01:50" valueOffset:150];
    [printer appendTitle:@"订单:" value:@"4000020160427100150" valueOffset:150];
    [printer appendText:@"地址:深圳市南山区学府路东深大店" alignment:HLTextAlignmentLeft];
    
    [printer appendSeperatorLine];
    [printer appendLeftText:@"商品" middleText:@"数量" rightText:@"单价" isTitle:YES];
    
    [printer appendSeperatorLine];
    
    CGFloat total = 37.0;
    NSString *totalStr = [NSString stringWithFormat:@"%.2f", total];
    [printer appendTitle:@"总计:" value:totalStr];
    [printer appendTitle:@"实收:" value:@"100.00"];
    NSString *leftStr = [NSString stringWithFormat:@"%.2f", 100.00 - total];
    [printer appendTitle:@"找零:" value:leftStr];
    
    [printer appendSeperatorLine];
    // 二维码
    [printer appendText:@"位图方式打印二维码" alignment:HLTextAlignmentCenter];
    [printer appendQRCodeWithInfo:@"www.baidu.com"];
    [printer appendSeperatorLine];
    
    [printer appendText:@"指令方式打印二维码" alignment:HLTextAlignmentCenter];
    [printer appendQRCodeWithInfo:@"www.baidu.com" size:12];
    [printer appendSeperatorLine];
    
    // 图片
    [printer appendImage:[UIImage imageNamed:@"ico180"] alignment:HLTextAlignmentCenter maxWidth:300];
    [printer appendFooter:nil];
     */
    
    return printer;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.peripherals.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"TableviewCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"TableviewCell"];
    }
    CBPeripheral* cbPeripheral = [self.peripherals objectAtIndex:indexPath.row];
    
    cell.textLabel.text = cbPeripheral.name;
    
    if ([self.peripheral isEqual:cbPeripheral]) {
        if (self.peripheral.state == CBPeripheralStateConnected) {
            cell.detailTextLabel.text = @"已连接";
        } else if (self.peripheral.state == CBPeripheralStateConnecting) {
            cell.detailTextLabel.text = @"链接中";
        } else if (self.peripheral.state == CBPeripheralStateDisconnecting) {
            cell.detailTextLabel.text = @"断开中";
        } else {
            cell.detailTextLabel.text = nil;
        }
    } else {
        cell.detailTextLabel.text = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CBPeripheral* cbPeripheral = [self.peripherals objectAtIndex:indexPath.row];
    [[MKBlueToothPrinter sharedInstance] connectPeripheral:cbPeripheral];
}

@end
