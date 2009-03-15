#import <Foundation/Foundation.h>
#import "NDFiber.h"

@interface TestClass : NSObject
{
@public
	NSString		* name;
	BOOL			continueExecution;
	NDFiber			* nextFiber;
	int				count;
}

+ (id)testClassWithName:(NSString *)name count:(unsigned int)count;
- (id)intiWithName:(NSString *)name count:(unsigned int)count;
- (void)entry:(id)ignored;

@end

int main (int argc, const char * argv[])
{
    NSAutoreleasePool	* pool = [[NSAutoreleasePool alloc] init];
	TestClass			* theA = [TestClass testClassWithName:@"A" count:10],
						* theB = [TestClass testClassWithName:@"B" count:22];
	NDFiber				* theMainFiber = [NDFiber mainFiber],
						* theFiberA = [NDFiber fiberWithTarget:theA selector:@selector(entry:) object:nil],
						* theFiberB = [NDFiber fiberWithTarget:theB selector:@selector(entry:) object:nil];

	[theMainFiber setName:@"main fiber"];
	[theFiberA setName:@"main A"];
	[theFiberB setName:@"main B"];

	theA->nextFiber = [theFiberB retain];
	theB->nextFiber = [theMainFiber retain];
	
//	[theFiberB start];
//	[theFiberA start];

	for( int i = 0; i < 10; i++ )
	{
		NSLog( @"main fiber = %d\n", i );
		[theFiberA continue];
		NSCParameterAssert( ![theMainFiber isFinished] );
		NSCParameterAssert( ![theFiberA isFinished] );
		NSCParameterAssert( ![theFiberB isFinished] );
	}
	
	theA->continueExecution = NO;
	theB->continueExecution = NO;

	NSLog( @"main fiber = finished\n" );
	[theFiberA continue];
	[theFiberB continue];

	NSCParameterAssert( ![theMainFiber isFinished] );
	NSCParameterAssert( [theFiberA isFinished] );
	NSCParameterAssert( [theFiberB isFinished] );
	/*
		This should throw an NDFiberSucceedToFinishedFiberException excpetion
	 */
	@try
	{
		[theFiberA continue];
		NSCParameterAssert( YES );
	}
	@catch  (NSException * anException)
	{
		NSCParameterAssert( [[anException name] isEqualToString:NDFiberSucceedToFinishedFiberException] );
		NSLog( @"exception %@", anException );
	}

	[pool drain];
    return 0;
}


@implementation TestClass : NSObject

+ (id)testClassWithName:(NSString *)aName count:(unsigned int)aCount
{
	return [[[self alloc] intiWithName:aName count:aCount] autorelease];
}

- (id)intiWithName:(NSString *)aName count:(unsigned int)aCount
{
	if( (self = [self init]) != nil )
	{
		name = [aName retain];
		count = aCount;
		nextFiber = nil;
		continueExecution = YES;
	}
	return self;
}

- (void)dealloc
{
	[name release];
	[nextFiber release];
	[super dealloc];
}

- (void)entry:(id)ignored
{

	while( continueExecution )
	{
		NSLog( @"%@ = %d\n", self, count++ );
		[nextFiber continue];
	} 
	NSLog( @"%@ = finished\n", self );
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"fiber %@", name];
}

@end

