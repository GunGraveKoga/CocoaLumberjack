#import <ObjFW/OFObject.h>
#import "DDLog.h"

@class DDLogFileInfo;
@class OFString;
@class OFArray;
@class OFConstantString;
@class OFFile;
@class OFTimer;
@class OFDictionary;


// Default configuration and safety/sanity values.
// 
// maximumFileSize         -> DEFAULT_LOG_MAX_FILE_SIZE
// rollingFrequency        -> DEFAULT_LOG_ROLLING_FREQUENCY
// maximumNumberOfLogFiles -> DEFAULT_LOG_MAX_NUM_LOG_FILES
// 
// You should carefully consider the proper configuration values for your application.

#define DEFAULT_LOG_MAX_FILE_SIZE     (1024 * 1024)   //  1 MB
#define DEFAULT_LOG_ROLLING_FREQUENCY (60 * 60 * 24)  // 24 Hours
#define DEFAULT_LOG_MAX_NUM_LOG_FILES (5)             //  5 Files


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// The LogFileManager protocol is designed to allow you to control all aspects of your log files.
// 
// The primary purpose of this is to allow you to do something with the log files after they have been rolled.
// Perhaps you want to compress them to save disk space.
// Perhaps you want to upload them to an FTP server.
// Perhaps you want to run some analytics on the file.
// 
// A default LogFileManager is, of course, provided.
// The default LogFileManager simply deletes old log files according to the maximumNumberOfLogFiles property.
// 
// This protocol provides various methods to fetch the list of log files.
// 
// There are two variants: sorted and unsorted.
// If sorting is not necessary, the unsorted variant is obviously faster.
// The sorted variant will return an array sorted by when the log files were created,
// with the most recently created log file at index 0, and the oldest log file at the end of the array.
// 
// You can fetch only the log file paths (full path including name), log file names (name only),
// or an array of DDLogFileInfo objects.
// The DDLogFileInfo class is documented below, and provides a handy wrapper that
// gives you easy access to various file attributes such as the creation date or the file size.

@protocol DDLogFileManager <OFObject>
@required

// Public properties

@property (readwrite, assign) uint32_t maximumNumberOfLogFiles;

// Public methods

- (OFString *)logsDirectory;

- (OFArray *)unsortedLogFilePaths;
- (OFArray *)unsortedLogFileNames;
- (OFArray *)unsortedLogFileInfos;

- (OFArray *)sortedLogFilePaths;
- (OFArray *)sortedLogFileNames;
- (OFArray *)sortedLogFileInfos;

// Private methods (only to be used by DDFileLogger)

- (OFString *)createNewLogFile;

@optional

// Notifications from DDFileLogger

- (void)didArchiveLogFile:(OFString *)logFilePath;
- (void)didRollAndArchiveLogFile:(OFString *)logFilePath;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Default log file manager.
// 
// All log files are placed inside the logsDirectory.
// On Mac, this is in ~/Library/Application Support/<Application Name>/Logs.
// On iPhone, this is in ~/Documents/Logs.
// 
// Log files are named "log-<uuid>.txt",
// where uuid is a 6 character hexadecimal consisting of the set [0123456789ABCDEF].
// 
// Archived log files are automatically deleted according to the maximumNumberOfLogFiles property.

@interface DDLogFileManagerDefault : OFObject <DDLogFileManager>
{
	uint32_t _maximumNumberOfLogFiles;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Most users will want file log messages to be prepended with the date and time.
// Rather than forcing the majority of users to write their own formatter,
// we will supply a logical default formatter.
// Users can easily replace this formatter with their own by invoking the setLogFormatter method.
// It can also be removed by calling setLogFormatter, and passing a nil parameter.
// 
// In addition to the convenience of having a logical default formatter,
// it will also provide a template that makes it easy for developers to copy and change.

@interface DDLogFileFormatterDefault : OFObject <DDLogFormatter>
{
	OFConstantString *_dateFormat;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DDFileLogger : OFObject <DDLogger>
{
	id <DDLogFormatter> formatter;
	id <DDLogFileManager> _logFileManager;
	
	DDLogFileInfo *currentLogFileInfo;
	OFFile *currentLogFileHandle;
	
	OFTimer *rollingTimer;
	
	uint64_t _maximumFileSize;
	of_time_interval_t _rollingFrequency;
}

- (id)init;
- (id)initWithLogFileManager:(id <DDLogFileManager>)logFileManager;

// Configuration
// 
// maximumFileSize:
//   The approximate maximum size to allow log files to grow.
//   If a log file is larger than this value after a write,
//   then the log file is rolled.
// 
// rollingFrequency
//   How often to roll the log file.
//   The frequency is given as an NSTimeInterval, which is a double that specifies the interval in seconds.
//   Once the log file gets to be this old, it is rolled.
// 
// Both the maximumFileSize and the rollingFrequency are used to manage rolling.
// Whichever occurs first will cause the log file to be rolled.
// 
// For example:
// The rollingFrequency is 24 hours,
// but the log file surpasses the maximumFileSize after only 20 hours.
// The log file will be rolled at that 20 hour mark.
// A new log file will be created, and the 24 hour timer will be restarted.
// 
// logFileManager
//   Allows you to retrieve the list of log files,
//   and configure the maximum number of archived log files to keep.

@property (readwrite, assign) uint64_t maximumFileSize;

@property (readwrite, assign) of_time_interval_t rollingFrequency;

@property (nonatomic, readonly) id <DDLogFileManager> logFileManager;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// DDLogFileInfo is a simple class that provides access to various file attributes.
// It provides good performance as it only fetches the information if requested,
// and it caches the information to prevent duplicate fetches.
// 
// It was designed to provide quick snapshots of the current state of log files,
// and to help sort log files in an array.
// 
// This class does not monitor the files, or update it's cached attribute values if the file changes on disk.
// This is not what the class was designed for.
// 
// If you absolutely must get updated values,
// you can invoke the reset method which will clear the cache.

@interface DDLogFileInfo : OFObject
{
	OFString *_filePath;
	OFString *_fileName;
	
	OFDictionary *_fileAttributes;
	
	OFDate *_creationDate;
	OFDate *_modificationDate;
	
	uint64_t _fileSize;
}

@property (nonatomic, readonly) OFString *filePath;
@property (nonatomic, readonly) OFString *fileName;

@property (nonatomic, readonly) OFDictionary *fileAttributes;

@property (nonatomic, readonly) OFDate *creationDate;
@property (nonatomic, readonly) OFDate *modificationDate;

@property (nonatomic, readonly) uint64_t fileSize;

@property (nonatomic, readonly) of_time_interval_t age;

@property (nonatomic, readwrite) bool isArchived;

+ (id)logFileWithPath:(OFString *)filePath;

- (id)initWithFilePath:(OFString *)filePath;

- (void)reset;
- (void)renameFile:(OFString *)newFileName;

// Normal use of extended attributes used everywhere else,
// such as on Macs and on iPhone devices.

- (bool)hasExtendedAttributeWithName:(OFString *)attrName;

- (void)addExtendedAttributeWithName:(OFString *)attrName;
- (void)removeExtendedAttributeWithName:(OFString *)attrName;


- (of_comparison_result_t)reverseCompareByCreationDate:(DDLogFileInfo *)another;
- (of_comparison_result_t)reverseCompareByModificationDate:(DDLogFileInfo *)another;

@end
