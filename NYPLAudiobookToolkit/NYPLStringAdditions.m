#import "NYPLStringAdditions.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NYPLStringAdditions

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
