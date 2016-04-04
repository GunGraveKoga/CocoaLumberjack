#import <ObjFW/ObjFW.h>
#import "DDTTYLogger.h"
#import "OFProcessInfo.h"

@interface DDTTYLogger ()
@property(nonatomic, copy, readwrite)OFString* app;
@property(nonatomic, copy, readwrite)OFNumber* pid;
@end

static DDTTYLogger *__sharedInstance = nil;;

@implementation DDTTYLogger

@synthesize app = _app;
@synthesize pid = _pid;
@synthesize logFormatter = _logFormatter;

/**
 * The runtime sends initialize to each class in a program exactly one time just before the class,
 * or any class that inherits from it, is sent its first message from within the program. (Thus the
 * method may never be invoked if the class is not used.) The runtime sends the initialize message to
 * classes in a thread-safe manner. Superclasses receive this message before their subclasses.
 *
 * This method may also be called directly (assumably by accident), hence the safety mechanism.
 **/
+ (void)initialize
{
	if (self == [DDTTYLogger class]) {
		if (!__sharedInstance) {
			__sharedInstance = [[DDTTYLogger alloc] init];
		}
	}
}

+ (instancetype)sharedInstance
{
	return __sharedInstance;
}

- (instancetype)init
{
	if (__sharedInstance)
		@throw [OFInitializationFailedException exceptionWithClass:[DDTTYLogger class]];

	self = [super init];

	isaTTY = isatty(STDERR_FILENO);

	if (isaTTY) {

		self.app = [[OFProcessInfo processInfo] processName];
		self.pid = [OFNumber numberWithUInt32:[[OFProcessInfo processInfo] processId]];
	}
	
	return self;
}

- (void)logMessage:(DDLogMessage *)logMessage
{
	OFString *logMsg = logMessage.logMsg;
	
	if (self.logFormatter) {
		logMsg = [self.logFormatter formatLogMessage:logMessage];
	}
	
	if (logMsg)
	{
		
		if (isaTTY)
		{

			// Here is our format: "%@ %@[%@:%@] %@", timestamp, appName, processID, threadID, logMsg
			OFString* consoleMessage = [OFString stringWithFormat:@"%04d-%02d-%02d %02d:%02d:%02d.%03d %@[%@:%@]: %@", //solve problem falldown with GCD
																			logMessage.timestamp.localYear, 
																			logMessage.timestamp.localMonthOfYear, 
																			logMessage.timestamp.localDayOfMonth,
																			logMessage.timestamp.localHour,
																			logMessage.timestamp.minute,
																			logMessage.timestamp.second,
																			logMessage.timestamp.microsecond / 1000,
																			self.app,
																			self.pid,
																			logMessage.threadID,
																			logMsg];
			
			if ([logMsg hasSuffix:@"\n"])
				[of_stderr writeString:consoleMessage];
			else
				[of_stderr writeLine:consoleMessage];
		}
	}
}

- (OFString *)loggerName
{
	return @"cocoa.lumberjack.TTYLogger";
}

- (void)dealloc
{
	[_app release];
	[_pid release];

	[super dealloc];
}

@end
