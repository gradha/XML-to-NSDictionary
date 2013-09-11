//
//  XMLReader.m
//

#import "XMLReader.h"

NSString *const kXMLReaderTextNodeKey = @"text";

@interface XMLReader (Internal)

- (id)initWithError:(NSError **)error;
- (NSDictionary *)objectWithData:(NSData *)data;

@end

@implementation NSDictionary (XMLReaderNavigation)

- (id)retrieveForPath:(NSString *)navPath {
    
    // Split path on dots
    NSArray *pathItems = [navPath componentsSeparatedByString:@"."];
    
    // Enumerate through array
    NSEnumerator *e = [pathItems objectEnumerator];
    NSString *path;

    // Set first branch from self
    id branch = [self objectForKey:[e nextObject]];
    int count = 1;
    while (path = [e nextObject]) {
        
        // Check if this branch is an NSArray
        if ([branch isKindOfClass:[NSArray class]]) {
            
            if ([path isEqualToString:@"last"]) {
                branch = [branch lastObject];
            } else {
                if ([branch count] > [path intValue]) {
                    branch = [branch objectAtIndex:[path intValue]];
                } else {
                    branch = nil;
                }
            }
            
        } else {
            
            //branch is assumed to be an NSDictionary
            branch = [branch objectForKey:path];
            
        }
        
        count++;
    }
    
    return branch;
}

/// Safe wrapper round retrieveForPath, returns nil if the object is not a dict.
- (NSDictionary*)dictionaryForPath:(NSString*)navPath
{
    id ret = [self retrieveForPath:navPath];
    if ([ret isKindOfClass:[NSDictionary class]])
        return ret;
    else
        return nil;
}

/// Wraps around dictionaryForPath to retrieve the text key/value safely.
- (NSString*)textForPath:(NSString*)navPath
{
    id ret = [self dictionaryForPath:navPath][kXMLReaderTextNodeKey];
    if ([ret isKindOfClass:[NSString class]])
        return ret;
    else
        return nil;
}

- (NSString*)trimmedTextForPath:(NSString*)navPath
{
    return [[self textForPath:navPath] stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end



@implementation XMLReader

#pragma mark -
#pragma mark Public methods

+ (NSDictionary *)dictionaryForXMLData:(NSData *)data error:(NSError **)error {
	
    XMLReader *reader = [[XMLReader alloc] initWithError:error];
    NSDictionary *rootDictionary = [reader objectWithData:data];
    [reader release];
    return rootDictionary;
}

+ (NSDictionary *)dictionaryForXMLString:(NSString *)string error:(NSError **)error {
	
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [XMLReader dictionaryForXMLData:data error:error];
}

#pragma mark -
#pragma mark Parsing

- (id)initWithError:(NSError **)error {
	
    if (self == [super init]) {
	
        errorPointer = error;
    }
    return self;
}

- (void)dealloc {
	
    [dictionaryStack release];
    [textInProgress release];
    [super dealloc];
}

- (NSDictionary *)objectWithData:(NSData *)data {
	
    // Clear out any old data
    [dictionaryStack release];
    [textInProgress release];
    
    dictionaryStack = [[NSMutableArray alloc] init];
    textInProgress = [[NSMutableString alloc] init];
    
    // Initialize the stack with a fresh dictionary
    [dictionaryStack addObject:[NSMutableDictionary dictionary]];
    
    // Parse the XML
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = self;
    BOOL success = [parser parse];
    
    // Return the stack's root dictionary on success
    if (success){
	
        NSDictionary *resultDict = [dictionaryStack objectAtIndex:0]; 

		[parser release];
        return resultDict;
    }
               
	[parser release];
    return nil;
}

#pragma mark -
#pragma mark NSXMLParserDelegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	
    // Get the dictionary for the current level in the stack
    NSMutableDictionary *parentDict = [dictionaryStack lastObject];

    // Create the child dictionary for the new element, and initilaize it with the attributes
    NSMutableDictionary *childDict = [NSMutableDictionary dictionary];
    [childDict addEntriesFromDictionary:attributeDict];
    
    // If there's already an item for this key, it means we need to create an array
    id existingValue = [parentDict objectForKey:elementName];
    if (existingValue) {
        NSMutableArray *array = nil;
        if ([existingValue isKindOfClass:[NSMutableArray class]])
        {
            // The array exists, so use it
            array = (NSMutableArray *) existingValue;
        }
        else
        {
            // Create an array if it doesn't exist
            array = [NSMutableArray array];
            [array addObject:existingValue];

            // Replace the child dictionary with an array of children dictionaries
            [parentDict setObject:array forKey:elementName];
        }
        
        // Add the new child dictionary to the array
        [array addObject:childDict];
    }
    else {
	
        // No existing value, so update the dictionary
        [parentDict setObject:childDict forKey:elementName];
    }
    
    // Update the stack
    [dictionaryStack addObject:childDict];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	
    // Update the parent dict with text info
    NSMutableDictionary *dictInProgress = [dictionaryStack lastObject];
    
    // Set the text property
    if ([textInProgress length] > 0) {
	
        [dictInProgress setObject:textInProgress forKey:kXMLReaderTextNodeKey];

        // Reset the text
        [textInProgress release];
        textInProgress = [[NSMutableString alloc] init];
    }
    
    // Pop the current dict
    [dictionaryStack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    // Build the text value
    [textInProgress appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    // Set the error pointer to the parser's error object
    *errorPointer = parseError;
}

@end
