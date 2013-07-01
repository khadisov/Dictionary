//
//  Dictionary.m
//  Dictionary
//
//  Created by Forrest Ye on 6/24/13.
//
//

#import "Dictionary.h"
#import "UIKit/UITextChecker.h"
#import "UIKit/UIReferenceLibraryViewController.h"

//#include <stdio.h>

# pragma mark - NSArray ReadWriteAsTXT addition


@interface NSArray (ReadWriteAsTXT)

- (void)writeAsTXTToFile:(NSString *)path;

+ (NSArray *)arrayWithTXTContentsOfFile:(NSString *)path;

@end


@implementation NSArray (ReadWriteAsTXT)


- (void)writeAsTXTToFile:(NSString *)path {
  NSMutableString *result = [@"" mutableCopy];

  for (NSString *term in self) {
    [result appendString:term];
    [result appendString:@"\n"];
  }

  [result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


+ (NSArray *)arrayWithTXTContentsOfFile:(NSString *)path {
// read file line by line using C is roughly 1 time slower than obj-c implementation. hmm.

//  NSMutableArray *result = [NSMutableArray arrayWithCapacity:100000];
//
//  FILE *file = fopen([path UTF8String], "r");
//
//  if (file) {
//    while(!feof(file)) {
//      char *line = NULL;
//      size_t linecap = 0;
//      ssize_t linelen;
//      while ((linelen = getline(&line, &linecap, file)) > 0) {
//        [result addObject:[NSString stringWithCString:line encoding:NSUTF8StringEncoding]];
//      }
//    }
//  }
//
//  fclose(file);
//
//  return result;

  return [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
}


@end


# pragma mark - Dictionary


@interface Dictionary ()

@property UITextChecker *textChecker;

@end


@implementation Dictionary


# pragma mark - object life cycle


+ (instancetype)sharedInstance {
  static Dictionary *_instance = nil;

  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    _instance = [[Dictionary alloc] init];
  });

  return _instance;
}


- (instancetype)init {
  self = [super init];

  [self reloadCache];

  _textChecker = [[UITextChecker alloc] init];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveCache) name:UIApplicationDidEnterBackgroundNotification object:nil];

  return self;
}


# pragma mark - cache manipulation


- (void)reloadCache {
  _validTermsCache = [NSMutableSet setWithArray:[NSArray arrayWithTXTContentsOfFile:[self validTermsCacheFilePath]]];
  NSLog(@"%d valid terms read", self.validTermsCache.count);

  _invalidTermsCache = [NSMutableSet setWithArray:[NSArray arrayWithTXTContentsOfFile:[self invalidTermsCacheFilePath]]];
  NSLog(@"%d invalid terms read", self.invalidTermsCache.count);
}


- (void)saveCache {
  NSMutableArray *array = [@[] mutableCopy];
  for (NSString *term in self.validTermsCache) {
    [array addObject:term];
  }

  [array writeAsTXTToFile:[self validTermsCacheFilePath]];
  NSLog(@"%d valid terms written", array.count);

  array = [@[] mutableCopy];
  for (NSString *term in self.invalidTermsCache) {
    [array addObject:term];
  }

  [array writeAsTXTToFile:[self invalidTermsCacheFilePath]];
  NSLog(@"%d invalid terms written", array.count);
}


- (NSString *)validTermsCacheFilePath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cacheDirectory = [paths objectAtIndex:0];

  return [cacheDirectory stringByAppendingPathComponent:@"validTerms.txt"];
}


- (NSString *)invalidTermsCacheFilePath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cacheDirectory = [paths objectAtIndex:0];

  return [cacheDirectory stringByAppendingPathComponent:@"invalidTerms.txt"];
}


# pragma mark - definition / completion lookup && guesses


- (BOOL)hasDefinitionForTerm:(NSString *)term {
  NSString *lowercaseTerm = [term lowercaseString];

  if ([self.validTermsCache containsObject:lowercaseTerm]) {
    return YES;
  }

  if ([self.invalidTermsCache containsObject:lowercaseTerm]) {
    return NO;
  }

  BOOL hasDefinition = [UIReferenceLibraryViewController dictionaryHasDefinitionForTerm:lowercaseTerm];

  if (hasDefinition) {
    [self.validTermsCache addObject:lowercaseTerm];
  } else {
    [self.invalidTermsCache addObject:lowercaseTerm];
  }

  return hasDefinition;
}


- (NSArray *)guessesForTerm:(NSString *)term {
  return [self.textChecker guessesForWordRange:NSMakeRange(0, [term length]) inString:term language:@"en_US"];
}


- (NSArray *)completionsForTerm:(NSString *)term {
  return [self.textChecker completionsForPartialWordRange:NSMakeRange(0, [term length]) inString:term language:@"en_US"];
}


@end
