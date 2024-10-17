// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "./include/webview_flutter_wkwebview/FWFScriptMessageHandlerHostApi.h"
#import "./include/webview_flutter_wkwebview/FWFDataConverters.h"
#import <Photos/Photos.h>
@interface FWFScriptMessageHandlerFlutterApiImpl ()
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFScriptMessageHandlerFlutterApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self initWithBinaryMessenger:binaryMessenger];
  if (self) {
    _instanceManager = instanceManager;
  }
  return self;
}

- (long)identifierForHandler:(FWFScriptMessageHandler *)instance {
  return [self.instanceManager identifierWithStrongReferenceForInstance:instance];
}

- (void)didReceiveScriptMessageForHandler:(FWFScriptMessageHandler *)instance
                    userContentController:(WKUserContentController *)userContentController
                                  message:(WKScriptMessage *)message
                               completion:(void (^)(FlutterError *_Nullable))completion {
  NSInteger userContentControllerIdentifier =
      [self.instanceManager identifierWithStrongReferenceForInstance:userContentController];
  FWFWKScriptMessageData *messageData = FWFWKScriptMessageDataFromNativeWKScriptMessage(message);
  [self didReceiveScriptMessageForHandlerWithIdentifier:[self identifierForHandler:instance]
                        userContentControllerIdentifier:userContentControllerIdentifier
                                                message:messageData
                                             completion:completion];
}
@end

@implementation FWFScriptMessageHandler
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [super initWithBinaryMessenger:binaryMessenger instanceManager:instanceManager];
  if (self) {
    _scriptMessageHandlerAPI =
        [[FWFScriptMessageHandlerFlutterApiImpl alloc] initWithBinaryMessenger:binaryMessenger
                                                               instanceManager:instanceManager];
  }
  return self;
}

//
//- (void)userContentController:(nonnull WKUserContentController *)userContentController
//      didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
//    NSLog(@"userContentController >>> %@",message.name);
//  [self.scriptMessageHandlerAPI didReceiveScriptMessageForHandler:self
//                                            userContentController:userContentController
//                                                          message:message
//                                                       completion:^(FlutterError *error) {
//                                                         NSAssert(!error, @"%@", error);
//                                                       }];
//}

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
    NSLog(@"Obj-c replyHandler >>> %@ %@",message.name,message.body);
   
    id  value = [self handleJSMessage:message];
    replyHandler(value,nil);
    NSLog(@"objc call js:  %@",value);
    [self.scriptMessageHandlerAPI didReceiveScriptMessageForHandler:self
                                              userContentController:userContentController
                                                            message:message
                                                         completion:^(FlutterError *error) {
                                                            NSAssert(!error, @"%@", error);
                                                         }];
}
// Define NSString constants to represent the enum cases
NSString *const AppFunctionForJSSetRegId = @"setRegId";
NSString *const AppFunctionForJSDownloadImage = @"downloadImage";
NSString *const AppFunctionForJSLaunchWhatsApp = @"launchWhatsApp";
NSString *const AppFunctionForJSLogin = @"login";
NSString *const AppFunctionForJSGetDeviceInformation = @"getDeviceInformation";
NSString *const AppFunctionForJSSaveAccount = @"saveAccount";
NSString *const AppFunctionForJSGetAllAccounts = @"getAllAccounts";
NSString *const AppFunctionForJSGetSysTraceId = @"getSysTraceId";

- (void)jsLaunchWhatsAppWithMessage:(NSString *)message {
    if (message == nil) {
        return;
    }

    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        return;
    }

    NSError *error;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

    if (error != nil || ![json isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *dic = (NSDictionary *)json;
    NSString *shareLink = dic[@"shareLink"] ?: @"";
    NSArray *phones = dic[@"phones"];
    
    // 构建 WhatsApp URL
    NSString *phoneNumber = phones.count > 0 ? phones[0] : @"";
    NSString *urlString = [NSString stringWithFormat:@"whatsapp://wa.me/%@?text=%@", phoneNumber, shareLink];

    NSString *encodeUrlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:encodeUrlString];

    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)jsDownloadImageWithBase64Image:(NSString *)base64Image {
    // 检查是否传入了 base64Image 字符串
    if (!base64Image) {
        return;
    }

    // 将 base64 字符串转换为图片
    UIImage *image = [self convertBase64ToImage:base64Image];
    if (!image) {
        return;
    }

    // 获取相册权限状态
    PHAuthorizationStatus authorizationStatus = [PHPhotoLibrary authorizationStatus];
    
    if (authorizationStatus == PHAuthorizationStatusNotDetermined) {
        // 如果是第一次请求相册权限
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            if (status == PHAuthorizationStatusAuthorized) {
                // 权限允许，保存图片
                [self saveImage:image];
            } else {
                NSLog(@"请在iPhone的“设置--隐私--相册”选项中，允许此App访问你的相册。");
            }
        }];
    } else if (authorizationStatus == PHAuthorizationStatusAuthorized) {
        // 如果权限已允许，直接保存图片
        [self saveImage:image];
    } else {
        // 权限不允许，提示用户去设置中打开权限
        NSLog(@"请在iPhone的“设置--隐私--相册”选项中，允许此App访问你的相册。");
    }
}

// Base64 字符串转换为 UIImage 的辅助方法
- (UIImage *)convertBase64ToImage:(NSString *)imageStr {
    // 检查 base64 字符串是否包含 "data:image/png;base64," 前缀，并移除该前缀
    if ([imageStr hasPrefix:@"data:image/png;base64,"]) {
        imageStr = [imageStr stringByReplacingOccurrencesOfString:@"data:image/png;base64," withString:@""];
    }
    
    // 将 base64 字符串转换为 NSData
    NSData *data = [[NSData alloc] initWithBase64EncodedString:imageStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    // 检查 NSData 是否有效，并尝试将其转换为 UIImage
    if (data) {
        UIImage *image = [UIImage imageWithData:data];
        return image;
    }
    
    // 如果无法解析 base64 字符串，则返回 nil
    return nil;
}


// 保存图片到相册的辅助方法
- (void)saveImage:(UIImage *)image {
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
}

- (void)jsSaveAccountWithMessage:(id)message {
    // 解析 message 参数，确保它是一个字符串并转成 JSON 对象
    if (![message isKindOfClass:[NSString class]]) {
        return;
    }
    
    NSString *messageString = (NSString *)message;
    NSData *messageData = [messageString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:messageData options:0 error:&error];
    
    if (error || ![jsonData isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    // 从 UserDefaults 获取现有的登录信息
    NSString *info = [[NSUserDefaults standardUserDefaults] stringForKey:AppFunctionForJSGetAllAccounts];
    NSMutableArray *infoArray = [NSMutableArray array];
    
    if (info != nil) {
        NSData *infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
        NSArray *existingInfoArray = [NSJSONSerialization JSONObjectWithData:infoData options:0 error:&error];
        if (!error && [existingInfoArray isKindOfClass:[NSArray class]]) {
            [infoArray addObjectsFromArray:existingInfoArray];
        }
    }
    
    // 移除与当前 accountName 相同的旧记录
    NSString *newAccountName = jsonData[@"accountName"];
    [infoArray filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *obj, NSDictionary *bindings) {
        return ![obj[@"accountName"] isEqualToString:newAccountName];
    }]];
    
    // 添加新记录
    [infoArray addObject:jsonData];
    
    // 将新的数据保存回 UserDefaults
    NSData *newInfoData = [NSJSONSerialization dataWithJSONObject:infoArray options:0 error:&error];
    if (error) {
        return;
    }
    
    NSString *newInfoString = [[NSString alloc] initWithData:newInfoData encoding:NSUTF8StringEncoding];
    [[NSUserDefaults standardUserDefaults] setObject:newInfoString forKey:AppFunctionForJSGetAllAccounts];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (id)jsGetAllAccounts {
    // 通过 UserDefaults 获取存储的登录信息
    NSString *loginInfoString = [[NSUserDefaults standardUserDefaults] stringForKey:AppFunctionForJSGetAllAccounts];

    if (loginInfoString == nil) {
        return nil;
    }

    NSData *jsonData = [loginInfoString dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData == nil) {
        return nil;
    }

    NSError *error;
    id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];

    if (error != nil) {
        return nil;
    }

    return jsonObj;
}


- (NSString *)jsGetDeviceInformation {
// 实现获取设备信息的逻辑
//return  @"5/DeliciousRecipesCommunity/5/com.joyndigital.foodapp/iOS/17.2/iPhone15Pro/iPhone/iPhone";
  
     
    // 当前版本号
    NSString *kAppCurrentVersion = @"1.1";
    
    // app 名称
    NSString *kAppDisplayName = @"app";
    
    // build 号
    NSString *kAppMinorVersion = @"11";
    
    // bundleId
    NSString *kBundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    // 系统名称，如：iOS
    NSString *kSystemName = [[UIDevice currentDevice] systemName];
    
    // 系统版本，如：14.6
    NSString *kSystemVersion = [[UIDevice currentDevice] systemVersion];
    
    // 设备名称
    NSString *kDeviceName = [[UIDevice currentDevice] name];
    
    // 设备型号，如：iPhone
    NSString *kDeviceModel = [[UIDevice currentDevice] model];
    
    // 设备区域化型号，如：A1533
    NSString *kLocalizedModel = [[UIDevice currentDevice] localizedModel];
    
    NSMutableString *text = [NSMutableString string];
    
    if (kAppCurrentVersion) {
        [text appendString:kAppCurrentVersion];
    }
    
    if (kAppDisplayName) {
        [text appendString:@"/"];
        [text appendString:kAppDisplayName];
    }
    
    if (kAppMinorVersion) {
        [text appendString:@"/"];
        [text appendString:kAppMinorVersion];
    }
    
    if (kBundleId) {
        [text appendString:@"/"];
        [text appendString:kBundleId];
    }
    
    [text appendFormat:@"/%@/%@/%@/%@/%@", kSystemName, kSystemVersion, kDeviceName, kDeviceModel, kLocalizedModel];

    
    return text;
}

    


- (NSString *)jsGetSysTraceId {
    // 实现获取系统追踪 ID 的逻辑
    return [[[NSUUID alloc] init] UUIDString];
}
 
- (id)handleJSMessage:(WKScriptMessage *)message {
    // Convert the message body to a string if possible
    NSString *stringBody = [message.body isKindOfClass:[NSString class]] ? (NSString *)message.body : nil;
    
    if ([message.name isEqualToString:AppFunctionForJSLaunchWhatsApp]) {
        [self jsLaunchWhatsAppWithMessage:stringBody];
    }
    // Uncomment the following when needed
    // else if ([message.name isEqualToString:AppFunctionForJSLogin]) {
    //     [self jsLoginWithMessage:stringBody];
    // }
    else if ([message.name isEqualToString:AppFunctionForJSSaveAccount]) {
        [self jsSaveAccountWithMessage:message.body];
    }
    else if ([message.name isEqualToString:AppFunctionForJSGetAllAccounts]) {
        return [self jsGetAllAccounts];
    }
    else if ([message.name isEqualToString:AppFunctionForJSGetDeviceInformation]) {
        return [self jsGetDeviceInformation];
    }
    else if ([message.name isEqualToString:AppFunctionForJSGetSysTraceId]) {
        return [self jsGetSysTraceId];
    }else if ([message.name isEqualToString:AppFunctionForJSDownloadImage]) {
          [self jsDownloadImageWithBase64Image:stringBody];
    }

    // If no case matches, return nil
    return nil;
}


@end

@interface FWFScriptMessageHandlerHostApiImpl ()
// BinaryMessenger must be weak to prevent a circular reference with the host API it
// references.
@property(nonatomic, weak) id<FlutterBinaryMessenger> binaryMessenger;
// InstanceManager must be weak to prevent a circular reference with the object it stores.
@property(nonatomic, weak) FWFInstanceManager *instanceManager;
@end

@implementation FWFScriptMessageHandlerHostApiImpl
- (instancetype)initWithBinaryMessenger:(id<FlutterBinaryMessenger>)binaryMessenger
                        instanceManager:(FWFInstanceManager *)instanceManager {
  self = [self init];
  if (self) {
    _binaryMessenger = binaryMessenger;
    _instanceManager = instanceManager;
  }
  return self;
}

- (FWFScriptMessageHandler *)scriptMessageHandlerForIdentifier:(NSNumber *)identifier {
  return (FWFScriptMessageHandler *)[self.instanceManager
      instanceForIdentifier:identifier.longValue];
}

- (void)createWithIdentifier:(NSInteger)identifier error:(FlutterError *_Nullable *_Nonnull)error {
  FWFScriptMessageHandler *scriptMessageHandler =
      [[FWFScriptMessageHandler alloc] initWithBinaryMessenger:self.binaryMessenger
                                               instanceManager:self.instanceManager];
  [self.instanceManager addDartCreatedInstance:scriptMessageHandler withIdentifier:identifier];
}
@end
