#import <ObjFW/OFObject.h>
#import "DDLog.h"

@class OFString;
@class OFNumber;
@class OFConstantString;


@interface DDTTYLogger : OFObject <DDLogger>
{
	bool isaTTY;
	
	OFString *_app; // Not null terminated
	OFNumber *_pid; // Not null terminated
	
	id <DDLogFormatter> _logFormatter;
}

@property(nonatomic, copy, readonly)OFString* app;
@property(nonatomic, copy, readonly)OFNumber* pid;
@property(nonatomic, copy, readwrite)id<DDLogFormatter> logFormatter;

+ (instancetype)sharedInstance;

@end
