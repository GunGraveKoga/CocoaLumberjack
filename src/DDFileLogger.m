#import <ObjFW/ObjFW.h>
#import "DDFileLogger.h"
#import "OFProcessInfo.h"

#define __weakSelfNonARC(name, self) void* name = &(*self)


//#import <sys/attr.h>
//#import <sys/xattr.h>

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
// 
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define LOG_LEVEL 0

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) of_log((frmt), ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) of_log((frmt), ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) of_log((frmt), ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) of_log((frmt), ##__VA_ARGS__); } while(0)

@interface DDLogFileManagerDefault (PrivateAPI)
- (void)deleteOldLogFiles;
@end

@interface DDFileLogger (PrivateAPI)
- (void)maybeRollLogFileDueToAge:(OFTimer *)aTimer;
- (void)maybeRollLogFileDueToSize;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDLogFileManagerDefault

@synthesize maximumNumberOfLogFiles = _maximumNumberOfLogFiles;


- (id)init
{
	self = [super init];
	
	self.maximumNumberOfLogFiles = DEFAULT_LOG_MAX_NUM_LOG_FILES;
	/*	
	NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		
	[self addObserver:self forKeyPath:@"maximumNumberOfLogFiles" options:kvoOptions context:nil];
	*/	
	NSLogVerbose(@"DDFileLogManagerDefault: logsDir:\n%@", [self logsDirectory]);
	NSLogVerbose(@"DDFileLogManagerDefault: sortedLogFileNames:\n%@", [self sortedLogFileNames]);
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([old isEqual:new])
	{
		// No change in value - don't bother with any processing.
		return;
	}
	
	if ([keyPath isEqualToString:@"maximumNumberOfLogFiles"])
	{
		NSLogInfo(@"DDFileLogManagerDefault: Responding to configuration change: maximumNumberOfLogFiles");
		
	#if GCD_AVAILABLE
		
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self deleteOldLogFiles];
			
			[pool release];
		};
		
		dispatch_async([DDLog loggingQueue], block);
		
	#else
		
		[self performSelector:@selector(deleteOldLogFiles)
		             onThread:[DDLog loggingThread]
		           withObject:nil
		        waitUntilDone:NO];
		
	#endif
	}
}
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Deleting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Deletes archived log files that exceed the maximumNumberOfLogFiles configuration value.
**/
- (void)deleteOldLogFiles
{
	NSLogVerbose(@"DDLogFileManagerDefault: deleteOldLogFiles");
	
	OFArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	uint32_t maxNumLogFiles = self.maximumNumberOfLogFiles;
	
	// Do we consider the first file?
	// We are only supposed to be deleting archived files.
	// In most cases, the first file is likely the log file that is currently being written to.
	// So in most cases, we do not want to consider this file for deletion.
	
	size_t count = [sortedLogFileInfos count];
	bool excludeFirstFile = false;
	
	if (count > 0)
	{
		DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:0];
		
		if (!logFileInfo.isArchived)
		{
			excludeFirstFile = YES;
		}
	}
	
	OFArray *sortedArchivedLogFileInfos;
	if (excludeFirstFile)
	{
		count--;
		sortedArchivedLogFileInfos = [sortedLogFileInfos objectsInRange:of_range(1, count)];
	}
	else
	{
		sortedArchivedLogFileInfos = sortedLogFileInfos;
	}
	
	for (size_t i = 0; i < count; i++)
	{
		if (i >= maxNumLogFiles)
		{
			DDLogFileInfo *logFileInfo = [sortedArchivedLogFileInfos objectAtIndex:i];
			
			NSLogInfo(@"DDLogFileManagerDefault: Deleting file: %@", logFileInfo.fileName);
			
			[[OFFileManager defaultManager] removeItemAtPath:logFileInfo.filePath];
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Log Files
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the path to the logs directory.
 * If the logs directory doesn't exist, this method automatically creates it.
**/
- (OFString *)logsDirectory
{
	OFDictionary *env = [[OFProcessInfo processInfo] environment];
	OFString *basePath = nil;
	
	#if defined(OF_WINDOWS)
    basePath = env[@"APPDATA"];
    #else
    basePath = env[@"HOME"];
    #endif
    OFString *baseDir = nil;
	if (basePath == nil) {
    	basePath = [[OFProcessInfo processInfo] processPath];
    	baseDir = [basePath stringByStandardizingPath];

    } else {
    	basePath = [basePath stringByAppendingPathComponent:@"ObjFW"];

    	if (![[OFFileManager defaultManager] directoryExistsAtPath:basePath])
    		[[OFFileManager defaultManager] createDirectoryAtPath:[basePath stringByStandardizingPath]];

    	basePath = [basePath stringByStandardizingPath];
		
		OFString *appName = [[OFProcessInfo processInfo] processName];
	
		baseDir = [basePath stringByAppendingPathComponent:appName];

		if (![[OFFileManager defaultManager] directoryExistsAtPath:baseDir])
			[[OFFileManager defaultManager] createDirectoryAtPath:[baseDir stringByStandardizingURLPath]];

    }

	
	OFString *logsDir = [baseDir stringByAppendingPathComponent:@"Logs"];

	logsDir = [logsDir stringByStandardizingPath];
	
	if(![[OFFileManager defaultManager] directoryExistsAtPath:logsDir])
		[[OFFileManager defaultManager] createDirectoryAtPath:logsDir];
	
	return logsDir;
}

- (bool)isLogFile:(OFString *)fileName
{
	// A log file has a name like "log-<uuid>.txt", where <uuid> is a HEX-string of 6 characters.
	// 
	// For example: log-DFFE99.txt
	//void* pool = objc_autoreleasePoolPush();
	bool hasProperPrefix = [fileName hasPrefix:@("log-")];
	
	bool hasProperLength = [fileName length] >= 10;
	
	
	if (hasProperPrefix && hasProperLength)
	{
		const of_unichar_t* chars = [@("0123456789ABCDEF") characters];
		
		OFString *hex = [fileName substringWithRange:of_range(4, 6)];
		size_t sHexCalculated = 0;

		for (size_t idx = 0; idx < [hex length]; ++idx) {
			for (size_t char_idx = 0; char_idx < 16; ++char_idx) {
				if (chars[char_idx] == [hex characterAtIndex:idx]) {
					sHexCalculated++;
					break;
				}
			}
		}

		if (sHexCalculated == [hex length]) {
			//objc_autoreleasePoolPop(pool);
			return true;
		}
	}

	//objc_autoreleasePoolPop(pool);
	return false;
}

/**
 * Returns an array of NSString objects,
 * each of which is the filePath to an existing log file on disk.
**/
- (OFArray *)unsortedLogFilePaths
{
	OFString *logsDirectory = [self logsDirectory];
	
	OFArray *fileNames = [[OFFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory];
	
	OFMutableArray *unsortedLogFilePaths = [OFMutableArray arrayWithCapacity:[fileNames count]];
	
	for (OFString *fileName in fileNames)
	{
		// Filter out any files that aren't log files. (Just for extra safety)
		
		if ([self isLogFile:fileName])
		{
			OFString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
			
			[unsortedLogFilePaths addObject:filePath];
		}
	}
	
	[unsortedLogFilePaths makeImmutable];
	return unsortedLogFilePaths;
}

/**
 * Returns an array of NSString objects,
 * each of which is the fileName of an existing log file on disk.
**/
- (OFArray *)unsortedLogFileNames
{
	OFArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	OFMutableArray *unsortedLogFileNames = [OFMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (OFString *filePath in unsortedLogFilePaths)
	{
		[unsortedLogFileNames addObject:[filePath lastPathComponent]];
	}
	
	[unsortedLogFileNames makeImmutable];
	return unsortedLogFileNames;
}

/**
 * Returns an array of DDLogFileInfo objects,
 * each representing an existing log file on disk,
 * and containing important information about the log file such as it's modification date and size.
**/
- (OFArray *)unsortedLogFileInfos
{
	OFArray *unsortedLogFilePaths = [self unsortedLogFilePaths];
	
	OFMutableArray *unsortedLogFileInfos = [OFMutableArray arrayWithCapacity:[unsortedLogFilePaths count]];
	
	for (OFString *filePath in unsortedLogFilePaths)
	{
		DDLogFileInfo *logFileInfo = [[DDLogFileInfo alloc] initWithFilePath:filePath];
		
		[unsortedLogFileInfos addObject:logFileInfo];
		[logFileInfo release];
	}
	
	[unsortedLogFileInfos makeImmutable];
	return unsortedLogFileInfos;
}

/**
 * Just like the unsortedLogFilePaths method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
**/
- (OFArray *)sortedLogFilePaths
{
	OFArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	OFMutableArray *sortedLogFilePaths = [OFMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFilePaths addObject:[logFileInfo filePath]];
	}
	
	[sortedLogFilePaths makeImmutable];
	return sortedLogFilePaths;
}

/**
 * Just like the unsortedLogFileNames method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
**/
- (OFArray *)sortedLogFileNames
{
	OFArray *sortedLogFileInfos = [self sortedLogFileInfos];
	
	OFMutableArray *sortedLogFileNames = [OFMutableArray arrayWithCapacity:[sortedLogFileInfos count]];
	
	for (DDLogFileInfo *logFileInfo in sortedLogFileInfos)
	{
		[sortedLogFileNames addObject:[logFileInfo fileName]];
	}
	
	[sortedLogFileNames makeImmutable];
	return sortedLogFileNames;
}

/**
 * Just like the unsortedLogFileInfos method, but sorts the array.
 * The items in the array are sorted by modification date.
 * The first item in the array will be the most recently modified log file.
**/
- (OFArray *)sortedLogFileInfos
{
	return [[self unsortedLogFileInfos] sortedArrayWithOptions:OF_ARRAY_SORT_DESCENDING];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Creation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Generates a short UUID suitable for use in the log file's name.
 * The result will have six characters, all in the hexadecimal set [0123456789ABCDEF].
**/
- (OFString *)generateShortUUID
{
	OFDate* dt = [OFDate date];
	OFString* dts = [dt dateStringWithFormat:@"%Y%m%d%H%M%S"];
	dts = [dts stringByAppendingFormat:@".%03d", [dt microsecond]/1000];
	dts = [[dts MD5Hash] substringWithRange:of_range(0, 6)];

	return [dts uppercaseString];
}

/**
 * Generates a new unique log file path, and creates the corresponding log file.
**/
- (OFString *)createNewLogFile
{
	// Generate a random log file name, and create the file (if there isn't a collision)
	
	OFString *logsDirectory = [self logsDirectory];
	do
	{
		OFString *fileName = [OFString stringWithFormat:@"log-%@.txt", [self generateShortUUID]];
		
		OFString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
		
		if (![[OFFileManager defaultManager] fileExistsAtPath:filePath])
		{
			NSLogVerbose(@"DDLogFileManagerDefault: Creating new log file: %@", fileName);
			
			OFFile* tmpFile = [OFFile fileWithPath:filePath mode:@"w+"];
			[tmpFile close];
			
			// Since we just created a new log file, we may need to delete some old log files
			[self deleteOldLogFiles];
			
			return filePath;
		}
		
	} while(true);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDLogFileFormatterDefault

- (id)init
{
	self = [super init];
	
	_dateFormat = @"%Y-%m-%d %H:%M:%S";
	
	return self;
}

- (OFString *)formatLogMessage:(DDLogMessage *)logMessage
{
	
	return [OFString stringWithFormat:@"%04d-%02d-%02d %02d:%02d:%02d.%03d %@[%d:%@]: %@", //solve problem falldown with GCD
		logMessage.timestamp.localYear, 
		logMessage.timestamp.localMonthOfYear, 
		logMessage.timestamp.localDayOfMonth,
		logMessage.timestamp.localHour,
		logMessage.timestamp.minute,
		logMessage.timestamp.second,
		logMessage.timestamp.microsecond / 1000,
		[[OFProcessInfo processInfo] processName],
		[[OFProcessInfo processInfo] processId],
		logMessage.threadID,
		logMessage.logMsg];
}

- (void)dealloc
{
	//[dateFormatter release];
	[super dealloc];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDFileLogger

@synthesize maximumFileSize = _maximumFileSize;
@synthesize rollingFrequency = _rollingFrequency;
@synthesize logFileManager = _logFileManager;

- (id)init
{
	DDLogFileManagerDefault *defaultLogFileManager = [[[DDLogFileManagerDefault alloc] init] autorelease];
	
	return [self initWithLogFileManager:defaultLogFileManager];
}

- (id)initWithLogFileManager:(id <DDLogFileManager>)aLogFileManager
{
	self = [super init];
	
	self.maximumFileSize = DEFAULT_LOG_MAX_FILE_SIZE;
	self.rollingFrequency = DEFAULT_LOG_ROLLING_FREQUENCY;
		
	_logFileManager = [aLogFileManager retain];
		
	formatter = [[DDLogFileFormatterDefault alloc] init];
	/*
	NSKeyValueObservingOptions kvoOptions = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
		
	[self addObserver:self forKeyPath:@"maximumFileSize"  options:kvoOptions context:nil];
	[self addObserver:self forKeyPath:@"rollingFrequency" options:kvoOptions context:nil];*/
	
	return self;
}

- (void)dealloc
{
	[formatter release];
	[_logFileManager release];
	
	[currentLogFileInfo release];
	
	[currentLogFileHandle close];
	[currentLogFileHandle release];
	
	[rollingTimer invalidate];
	[rollingTimer release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	NSNumber *old = [change objectForKey:NSKeyValueChangeOldKey];
	NSNumber *new = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([old isEqual:new])
	{
		// No change in value - don't bother with any processing.
		return;
	}
	
	if ([keyPath isEqualToString:@"maximumFileSize"])
	{
		NSLogInfo(@"DDFileLogger: Responding to configuration change: maximumFileSize");
		
	#if GCD_AVAILABLE
	
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self maybeRollLogFileDueToSize];
			
			[pool release];
		};
		
		dispatch_async([DDLog loggingQueue], block);
	#else
		
		[self performSelector:@selector(maybeRollLogFileDueToSize)
		             onThread:[DDLog loggingThread]
		           withObject:nil
		        waitUntilDone:NO];
		
	#endif
	}
	else if([keyPath isEqualToString:@"rollingFrequency"])
	{
		NSLogInfo(@"DDFileLogger: Responding to configuration change: rollingFrequency");
		
	#if GCD_AVAILABLE
		
		dispatch_block_t block = ^{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			[self maybeRollLogFileDueToAge:nil];
			
			[pool release];
		};
		
		dispatch_async([DDLog loggingQueue], block);
		
	#else
		
		[self performSelector:@selector(maybeRollLogFileDueToAge:)
		             onThread:[DDLog loggingThread]
		           withObject:nil
		        waitUntilDone:NO];
		
	#endif
	}
}
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Rolling
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scheduleTimerToRollLogFileDueToAge
{
	if (rollingTimer)
	{
		[rollingTimer invalidate];
		[rollingTimer release];
		rollingTimer = nil;
	}
	
	if (currentLogFileInfo == nil)
	{
		return;
	}
	
	OFDate *logFileCreationDate = [currentLogFileInfo creationDate];
	
	OFDate *logFileRollingDate = [logFileCreationDate dateByAddingTimeInterval:self.rollingFrequency];
	
	NSLogVerbose(@"DDFileLogger: scheduleTimerToRollLogFileDueToAge");
	
	NSLogVerbose(@"DDFileLogger: logFileCreationDate: %@", logFileCreationDate);
	NSLogVerbose(@"DDFileLogger: logFileRollingDate : %@", logFileRollingDate);
	
	rollingTimer = [[OFTimer scheduledTimerWithTimeInterval:[logFileRollingDate timeIntervalSinceNow]
	                                                 target:self
	                                               selector:@selector(maybeRollLogFileDueToAge)
	                                                repeats:false] retain];
}

- (void)rollLogFile
{
	NSLogVerbose(@"DDFileLogger: rollLogFile");
	
	[currentLogFileHandle close];
	[currentLogFileHandle release];
	currentLogFileHandle = nil;
	
	currentLogFileInfo.isArchived = true;
	
	if ([_logFileManager respondsToSelector:@selector(didRollAndArchiveLogFile:)])
	{
		[_logFileManager didRollAndArchiveLogFile:(currentLogFileInfo.filePath)];
	}
	
	[currentLogFileInfo release];
	currentLogFileInfo = nil;
}

- (void)maybeRollLogFileDueToAge
{
	if (currentLogFileInfo.age >= self.rollingFrequency)
	{
		NSLogVerbose(@"DDFileLogger: Rolling log file due to age...");
		
		[self rollLogFile];
	}
	else
	{
		[self scheduleTimerToRollLogFileDueToAge];
	}
}

- (void)maybeRollLogFileDueToSize
{
	
	if ([currentLogFileHandle isWriteBuffered])
		[currentLogFileHandle flushWriteBuffer];


	uint64_t sFileSize = (uint64_t)[[OFFileManager defaultManager] sizeOfFileAtPath:[[self currentLogFileInfo] filePath]];
	
	if (sFileSize >= self.maximumFileSize)
	{
		NSLogVerbose(@"DDFileLogger: Rolling log file due to size...");
		
		[self rollLogFile];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the log file that should be used.
 * If there is an existing log file that is suitable,
 * within the constraints of maximumFileSize and rollingFrequency, then it is returned.
 * 
 * Otherwise a new file is created and returned.
**/
- (DDLogFileInfo *)currentLogFileInfo
{
	if (currentLogFileInfo == nil)
	{
		OFArray *sortedLogFileInfos = [_logFileManager sortedLogFileInfos];
		
		if ([sortedLogFileInfos count] > 0)
		{
			DDLogFileInfo *mostRecentLogFileInfo = [sortedLogFileInfos objectAtIndex:0];
			
			bool useExistingLogFile = true;
			bool shouldArchiveMostRecent = false;
			
			if (mostRecentLogFileInfo.isArchived)
			{
				useExistingLogFile = false;
				shouldArchiveMostRecent = false;
			}
			else if (mostRecentLogFileInfo.fileSize >= self.maximumFileSize)
			{
				useExistingLogFile = false;
				shouldArchiveMostRecent = true;
			}
			else if (mostRecentLogFileInfo.age >= self.rollingFrequency)
			{
				useExistingLogFile = false;
				shouldArchiveMostRecent = true;
			}
			
			if (useExistingLogFile)
			{
				NSLogVerbose(@"DDFileLogger: Resuming logging with file %@", mostRecentLogFileInfo.fileName);
				
				currentLogFileInfo = [mostRecentLogFileInfo retain];
			}
			else
			{
				if (shouldArchiveMostRecent)
				{
					mostRecentLogFileInfo.isArchived = true;
					
					if ([_logFileManager respondsToSelector:@selector(didArchiveLogFile:)])
					{
						[_logFileManager didArchiveLogFile:(mostRecentLogFileInfo.filePath)];
					}
				}
			}
		}
		
		if (currentLogFileInfo == nil)
		{
			OFString *currentLogFilePath = [_logFileManager createNewLogFile];
			
			currentLogFileInfo = [[DDLogFileInfo alloc] initWithFilePath:currentLogFilePath];
		}
	}
	
	return currentLogFileInfo;
}

- (OFFile *)currentLogFileHandle
{
	if (currentLogFileHandle == nil)
	{
		OFString *logFilePath = [[self currentLogFileInfo] filePath];
		
		currentLogFileHandle = [[OFFile fileWithPath:logFilePath mode:@("a+")] retain];
		[currentLogFileHandle seekToOffset:0 whence:SEEK_END];
		
		if (currentLogFileHandle)
		{
			[self scheduleTimerToRollLogFileDueToAge];
		}
	}
	
	return currentLogFileHandle;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark DDLogger Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)logMessage:(DDLogMessage *)logMessage
{
	OFString *logMsg = logMessage.logMsg;
	
	if (formatter)
	{
		logMsg = [formatter formatLogMessage:logMessage];
	}
	
	if (logMsg)
	{
		if (![logMsg hasSuffix:@"\n"])
		{
			logMsg = [logMsg stringByAppendingString:@"\n"];
		}
		
		[[self currentLogFileHandle] writeString:logMsg];
		
		[self maybeRollLogFileDueToSize];
	}
}

- (id <DDLogFormatter>)logFormatter
{
    return formatter;
}

- (void)setLogFormatter:(id <DDLogFormatter>)logFormatter
{
    if (formatter != logFormatter)
	{
		[formatter release];
		formatter = [logFormatter retain];
	}
}

- (OFString *)loggerName
{
	return @"cocoa.lumberjack.fileLogger";
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#define XATTR_ARCHIVED_NAME  @"lumberjack.log.archived"


@implementation DDLogFileInfo

@synthesize filePath = _filePath;

@dynamic fileName;
@dynamic fileAttributes;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic fileSize;
@dynamic age;

@dynamic isArchived;


#pragma mark Lifecycle

+ (id)logFileWithPath:(OFString *)aFilePath
{
	return [[[DDLogFileInfo alloc] initWithFilePath:aFilePath] autorelease];
}

- (id)initWithFilePath:(OFString *)aFilePath
{
	self = [super init];
	
	_filePath = [aFilePath copy];

	id tmp = [self creationDate]; //Hack for creation date imitation
	tmp = nil;

	[_modificationDate release];
	_modificationDate = nil;
	
	return self;
}

- (void)dealloc
{
	[_filePath release];
	[_fileName release];
	
	[_fileAttributes release];
	
	[_creationDate release];
	[_modificationDate release];
	
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Standard Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (OFDictionary *)fileAttributes
{
	/*if (fileAttributes == nil)
	{
		fileAttributes = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] retain];
	}
	return fileAttributes;*/
	return [OFDictionary dictionary];
}

- (OFString *)fileName
{
	if (_fileName == nil)
	{
		_fileName = [[self.filePath lastPathComponent] retain];
	}
	return _fileName;
}

- (OFDate *)modificationDate
{
	if (_modificationDate == nil)
	{
		_modificationDate = [[[OFFileManager defaultManager] modificationTimeOfItemAtPath:self.filePath] retain];
	}
	
	return _modificationDate;
}

- (OFDate *)creationDate
{
	if (_creationDate == nil)
	{
	
		
		_creationDate = [[[OFFileManager defaultManager] modificationTimeOfItemAtPath:self.filePath] retain]; //Need to implement real file creation date
		
		
	}
	return _creationDate;
}

- (uint64_t)fileSize
{
	if (_fileSize == 0)
	{
		_fileSize = (uint64_t)[[OFFileManager defaultManager] sizeOfFileAtPath:self.filePath];
	}
	
	return _fileSize;
}

- (of_time_interval_t)age
{
	return [[self creationDate] timeIntervalSinceNow] * -1.0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Archiving
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (bool)isArchived
{
	
	return [self hasExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
}

- (void)setIsArchived:(bool)flag
{
	
	if (flag)
		[self addExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	else
		[self removeExtendedAttributeWithName:XATTR_ARCHIVED_NAME];
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Changes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)reset
{
	[_fileName release];
	_fileName = nil;
	
	[_fileAttributes release];
	_fileAttributes = nil;
	
	[_creationDate release];
	_creationDate = nil;
	
	[_modificationDate release];
	_modificationDate = nil;

	id tmp = [self creationDate]; //Hack for creation date
	tmp = nil;

	[_modificationDate release];
	_modificationDate = nil;
}

- (void)renameFile:(OFString *)newFileName
{
	// This method is only used on the iPhone simulator, where normal extended attributes are broken.
	// See full explanation in the header file.
	
	if (![newFileName isEqual:[self fileName]])
	{
		OFString *fileDir = [_filePath stringByDeletingLastPathComponent];
		
		OFString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];
		
		NSLogVerbose(@"DDLogFileInfo: Renaming file: '%@' -> '%@'", self.fileName, newFileName);
		
		@try {
			[[OFFileManager defaultManager] moveItemAtPath:_filePath toPath:newFilePath];
		}@catch(OFException* e) {
			NSLogError(@"DDLogFileInfo: Error renaming file (%@): %@", self.fileName, e);
		}
		
		[_filePath release];
		_filePath = [newFilePath retain];
		
		[self reset];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Attribute Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (bool)hasExtendedAttributeWithName:(OFString *)attrName
{
	//const char *path = [filePath UTF8String];
	//const char *name = [attrName UTF8String];
	
	//int result = getxattr(path, name, NULL, 0, 0, 0);
	
	return false;//(result >= 0);
}

- (void)addExtendedAttributeWithName:(OFString *)attrName
{
	//const char *path = [filePath UTF8String];
	//const char *name = [attrName UTF8String];
	
	//int result = setxattr(path, name, NULL, 0, 0, 0);
	
	if (!false)
	{
		NSLogError(@"DDLogFileInfo: setxattr(%@, %@): error = %i", attrName, self.fileName, 0);
	}
}

- (void)removeExtendedAttributeWithName:(NSString *)attrName
{
	//const char *path = [filePath UTF8String];
	//const char *name = [attrName UTF8String];
	
	//int result = removexattr(path, name, 0);
	
	if (!false)
	{
		NSLogError(@"DDLogFileInfo: removexattr(%@, %@): error = %i", attrName, self.fileName, 0);
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparisons
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (bool)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]])
	{
		DDLogFileInfo *another = (DDLogFileInfo *)object;
		
		return [_filePath isEqual:[another filePath]];
	}
	
	return false;
}

- (of_comparison_result_t)compare:(DDLogFileInfo *)another
{
	OFDate *us = [self creationDate];
	OFDate *them = [another creationDate];

	return [us compare:them];
}

- (of_comparison_result_t)reverseCompareByCreationDate:(DDLogFileInfo *)another
{
	OFDate *us = [self creationDate];
	OFDate *them = [another creationDate];
	
	of_comparison_result_t result = [us compare:them];
	
	if (result == OF_ORDERED_ASCENDING)
		return OF_ORDERED_DESCENDING;
	
	if (result == OF_ORDERED_DESCENDING)
		return OF_ORDERED_ASCENDING;
	
	return OF_ORDERED_SAME;
}

- (of_comparison_result_t)reverseCompareByModificationDate:(DDLogFileInfo *)another
{
	OFDate *us = [self modificationDate];
	OFDate *them = [another modificationDate];
	
	of_comparison_result_t result = [us compare:them];
	
	if (result == OF_ORDERED_ASCENDING)
		return OF_ORDERED_DESCENDING;
	
	if (result == OF_ORDERED_DESCENDING)
		return OF_ORDERED_ASCENDING;
	
	return OF_ORDERED_SAME;
}

@end
