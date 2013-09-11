//
//  XMLReader.h
//
//

#import <Foundation/Foundation.h>


@interface XMLReader : NSObject  <NSXMLParserDelegate> {
	
    NSMutableArray *dictionaryStack;
    NSMutableString *textInProgress;
    NSError **errorPointer;
}

+ (NSDictionary *)dictionaryForXMLData:(NSData *)data error:(NSError **)errorPointer;
+ (NSDictionary *)dictionaryForXMLString:(NSString *)string error:(NSError **)errorPointer;

@end

@interface NSDictionary (XMLReaderNavigation)

- (id)retrieveForPath:(NSString *)navPath;
- (NSDictionary*)dictionaryForPath:(NSString*)navPath;
- (NSString*)textForPath:(NSString*)navPath;
- (NSString*)trimmedTextForPath:(NSString*)navPath;

@end

