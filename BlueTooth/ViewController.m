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
            [strongSelf.tableView reloadData];
        } else if (connectErrorType == MKBTConnectErrorTypeTimeOut) {
            NSLog(@"蓝牙链接超时");
        } else if (connectErrorType == MKBTConnectErrorTypeNoConfig) {
            NSLog(@"蓝牙未配置");
        }
    } forKey:key];
    
    if ([[MKBlueToothPrinter sharedInstance] isConnected]) {
        // 重新进入页面的情况
        self.peripherals = [[MKBlueToothPrinter sharedInstance] discoverPeripherals];
        [self.tableView reloadData];
    } else {
        // 重新扫描手动、自动连接
        [[MKBlueToothPrinter sharedInstance] scanForPeripherals];
    }
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
    
    [printer appendText:@"#27商户平台" alignment:HLTextAlignmentCenter fontSize:HLFontSizeTitleMiddle];
    [printer appendNewLine];
    [printer appendText:@"李记三及第-宝体" alignment:HLTextAlignmentCenter fontSize:HLFontSizeTitleSmalle];
    [printer appendSeperatorLine];
    
    [printer appendText:@"期望送达时间：立即配送" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleSmalle];
    [printer appendText:@"下单时间：2021-11-15 11:27:27" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleSmalle];
    [printer appendSeperatorLine];
    
    [printer appendText:@"备注：少麻少辣，谢谢！！！" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendSeperatorLine];
    
    [printer appendLeftText:@"商品" middleText:@"数量" rightText:@"价格" isTitle:YES];
    [printer appendSeperatorLine];
    [printer appendLeftText:@"三及第汤河粉" middleText:@"1" rightText:@"￥13" isTitle:YES];
    [printer appendSeperatorLine];
    
    [printer appendTitle:@"打包费：" value:@"￥1"];
    [printer appendTitle:@"配送费：" value:@"￥2"];
    [printer appendTitle:@"优惠券：" value:@"-￥3"];
    [printer appendSeperatorLine];
    
    [printer appendText:@"用户实付：￥13" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendSeperatorLine];
    
    [printer appendText:@"广东华南理工" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendText:@"南苑10栋   403" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendText:@"郑先生" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendText:@"158******27" alignment:HLTextAlignmentLeft fontSize:HLFontSizeTitleMiddle];
    [printer appendNewLine];
    
    [printer appendQRCodeWithInfo:@"MD1232423434"];
    [printer appendNewLine];
    
    [printer appendNewLine];
    [printer appendNewLine];
    
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
    
    if (cbPeripheral.state == CBPeripheralStateConnected) {
        cell.detailTextLabel.text = @"已连接";
    } else if (cbPeripheral.state == CBPeripheralStateConnecting) {
        cell.detailTextLabel.text = @"链接中";
    } else if (cbPeripheral.state == CBPeripheralStateDisconnecting) {
        cell.detailTextLabel.text = @"断开中";
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
