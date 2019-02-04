#import "NYPLStringAdditions.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NYPLStringAdditions

+ (NSString *)fileSystemSafeBase64DecodedStringUsingEncoding:(NSStringEncoding)encoding forString:(NSString *)inputString
{
  NSMutableString *const s = [[[inputString stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
                               stringByReplacingOccurrencesOfString:@"_" withString:@"/"]
                              mutableCopy];

  while([s length] % 4) {
    [s appendString:@"="];
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
  return [[NSString alloc]
          initWithData:[[NSData alloc] initWithBase64EncodedString:s options:0]
          encoding:encoding];
#pragma clang diagnostic pop
}

+ (NSString *)fileSystemSafeBase64EncodedStringUsingEncoding:(NSStringEncoding)encoding forString:(NSString *)inputString
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
  return [[[[[inputString dataUsingEncoding:encoding] base64EncodedStringWithOptions:0]
            stringByTrimmingCharactersInSet:[NSCharacterSet
                                             characterSetWithCharactersInString:@"="]]
           stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
          stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
#pragma clang diagnostic pop
}

+ (NSString *)SHA256forString:(NSString *)inputString
{
  NSData *const input = [inputString dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char output[CC_SHA256_DIGEST_LENGTH];

  CC_SHA256(input.bytes, (CC_LONG)input.length, output);
  
  char s[CC_SHA256_DIGEST_LENGTH * 2 + 1];
  s[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
  
  const char *const hex = "0123456789abcdef";
  
  for(unsigned int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
    s[i * 2] = hex[output[i] / 16];
    s[i * 2 + 1] = hex[output[i] % 16];
  }
  
  return [[NSString alloc] initWithBytes:s
                                  length:(CC_SHA256_DIGEST_LENGTH * 2)
                                encoding:NSASCIIStringEncoding];
}

@end
