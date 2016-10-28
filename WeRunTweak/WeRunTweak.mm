//
//  WeChatTweak.mm
//  WeChatTweak
//
//  Created by 高石磊 on 2016/10/27.
//  Copyright (c) 2016年 __MyCompanyName__. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#import <Foundation/Foundation.h>
#import "CaptainHook/CaptainHook.h"
#include <notify.h> // not required; for examples only

// Objective-C runtime hooking using CaptainHook:
//   1. declare class using CHDeclareClass()
//   2. load class using CHLoadClass() or CHLoadLateClass() in CHConstructor
//   3. hook method using CHOptimizedMethod()
//   4. register hook using CHHook() in CHConstructor
//   5. (optionally) call old method using CHSuper()

/**
 *  修改微信步数#52000
 **/

static int StepCount = 5000;
static NSString *StepCountKey = @"StepCount";
static NSString *HookSettingsFile = @"HookSettings.txt";

CHDeclareClass(WCDeviceStepObject)

//宏格式：参数的个数，返回值的类型，类的名称，selector的名称，selector的类型，selector对应的参数的变量名。
CHMethod(0, unsigned int, WCDeviceStepObject, m7StepCount) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    if (!docDir){ return StepCount;}
    NSString *path = [docDir stringByAppendingPathComponent:HookSettingsFile];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    int value = ((NSNumber *)dict[StepCountKey]).intValue;
    if (value < 0) {
        return CHSuper(0, WCDeviceStepObject, m7StepCount);
    }
    return value;
}

CHDeclareClass(CMessageMgr);

CHMethod(2, void, CMessageMgr, AsyncOnAddMsg, id, arg1, MsgWrap, id, arg2) {
    CHSuper(2, CMessageMgr, AsyncOnAddMsg, arg1, MsgWrap, arg2);
    Ivar uiMessageTypeIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_uiMessageType");
    ptrdiff_t offset = ivar_getOffset(uiMessageTypeIvar);
    unsigned char *stuffBytes = (unsigned char *)(__bridge void *)arg2;
    NSUInteger m_uiMessageType = * ((NSUInteger *)(stuffBytes + offset));
    
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    id m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    
    Ivar nsContentIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsContent");
    id m_nsContent = object_getIvar(arg2, nsContentIvar);
    
    if (m_uiMessageType == 1) {
        //普通消息
        
        //微信的服务中心
        Method methodMMServiceCenter = class_getClassMethod(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
        IMP impMMSC = method_getImplementation(methodMMServiceCenter);
        id MMServiceCenter = impMMSC(objc_getClass("MMServiceCenter"), @selector(defaultCenter));
        //通讯录管理器
        id contactManager = ((id (*)(id, SEL, Class))objc_msgSend)(MMServiceCenter, @selector(getService:),objc_getClass("CContactMgr"));
        id selfContact = objc_msgSend(contactManager, @selector(getSelfContact));
        
        Ivar nsUsrNameIvar = class_getInstanceVariable([selfContact class], "m_nsUsrName");
        id m_nsUsrName = object_getIvar(selfContact, nsUsrNameIvar);
        BOOL isMesasgeFromMe = NO;
        if ([m_nsFromUsr isEqualToString:m_nsUsrName]) {
            //发给自己的消息
            isMesasgeFromMe = YES;
        }
        
        if (isMesasgeFromMe)
        {
            if ([m_nsContent rangeOfString:@"修改微信步数#"].location != NSNotFound) {
                NSArray *array = [m_nsContent componentsSeparatedByString:@"#"];
                if (array.count == 2) {
                    StepCount = ((NSNumber *)array[1]).intValue;
                    NSLog(@"微信步数已修改为 : %d", StepCount);
                }
            } else if([m_nsContent rangeOfString:@"恢复微信步数"].location != NSNotFound) {
                StepCount = -1;
                NSLog(@"微信步数已经恢复");
            }
            // save to file
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *docDir = [paths objectAtIndex:0];
            if (!docDir){ return;}
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            NSString *path = [docDir stringByAppendingPathComponent:HookSettingsFile];
            dict[StepCountKey] = [NSNumber numberWithInt:StepCount];
            [dict writeToFile:path atomically:YES];
        }
    }
}


__attribute__((constructor)) static void entry() {
    NSLog(@"微信步数燥起来!");
    CHLoadLateClass(WCDeviceStepObject);
    CHClassHook(0, WCDeviceStepObject,m7StepCount);
    
    CHLoadLateClass(CMessageMgr);
    CHClassHook(2, CMessageMgr, AsyncOnAddMsg, MsgWrap);
}
