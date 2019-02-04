#import <Foundation/Foundation.h>

@interface NYPLStringAdditions : NSObject

+ (NSString *)fileSystemSafeBase64DecodedStringUsingEncoding:(NSStringEncoding)encoding forString:(NSString *)inputString;

+ (NSString *)fileSystemSafeBase64EncodedStringUsingEncoding:(NSStringEncoding)encoding forString:(NSString *)inputString;

+ (NSString *)SHA256forString:(NSString *)inputString;

@end
