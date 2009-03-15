//
//  ExceptionsTest.m
//  NDFiber
//
//  Created by Nathan Day on 15/03/09.
//  Copyright 2009 Nathan Day. All rights reserved.
//

#import "NDFiber.h"
#import <Foundation/Foundation.h>

@interface TestClass : NSObject
{
	
}

+ (void)methodA:(NDFiber *)next;
+ (void)methodB:(NDFiber *)next;

@end

int main (int argc, const char * argv[])
{
    NSAutoreleasePool	* pool = [[NSAutoreleasePool alloc] init];
	[TestClass methodA:[NDFiber fiberWithTarget:[TestClass class] selector:@selector(methodB:) object:[NDFiber mainFiber]]];
	[pool drain];
}	



@implementation TestClass

+ (void)methodA:(NDFiber *)aNext
{
	NSString		* theExceptionName = [NSString stringWithFormat:@"ExceptionIn%s", _cmd];
	for( int i = 0; i < 50; i++ )
	{
		@try
		{
			NSLog( @"method %s, iteration %d", _cmd, i );
			[aNext continue];
			if( i == 20 )
				[NSException raise:theExceptionName format:@"Exception raised in method %s", _cmd];
		}
		@catch( NSException * anException )
		{
			NSAssert1( [[anException name] isEqualToString:theExceptionName], @"Exception Name is %@", [anException name] );
			NSLog( @"caught exception in method %s, iteration %d", _cmd, i );
		}
	}
}

+ (void)methodB:(NDFiber *)aNext
{
	NSString		* theExceptionName = [NSString stringWithFormat:@"ExceptionIn%s", _cmd];
	for( int i = 0; i < 50; i++ )
	{
		@try
		{
			NSLog( @"method %s, iteration %d", _cmd, i );
			[aNext continue];
			if( i == 30 )
				[NSException raise:theExceptionName format:@"Exception raised in method %s", _cmd];
		}
		@catch( NSException * anException )
		{
			NSAssert1( [[anException name] isEqualToString:theExceptionName], @"Exception Name is %@", [anException name] );
			NSLog( @"caught exception in method %s, iteration %d", _cmd, i );
		}
	}
}

@end
