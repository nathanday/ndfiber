//
//  AutoreleasePoolTest.m
//  NDFiber
//
//  Created by Nathan Day on 15/03/09.
//  Copyright 2009 Nathan Day. All rights reserved.
//

#import "NDFiber.h"
#import <Foundation/Foundation.h>

@interface TestClass : NSObject
{
	NSString		* name;
}

+ (id)autoreleaseTestClassWithName:(NSString*)name;
- (id)initWithName:(NSString*)name;

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

+ (id)autoreleaseTestClassWithName:(NSString*)aName
{
	return [[[self alloc] initWithName:aName] autorelease];
}

- (id)initWithName:(NSString*)aName
{
	if( (self = [self init]) != nil )
		name = [aName retain];
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"object named '%@'", name];
}

- (oneway void)release
{
	NSLog( @"Releasing %@ in fiber %@", self, [[NDFiber currentFiber] name] );
	[super release];
}

- (void)dealloc
{
	NSLog( @"Deallocating %@ in fiber %@", self, [[NDFiber currentFiber] name] );
	[super dealloc];
}

+ (void)methodA:(NDFiber *)aNext
{
	[[NDFiber currentFiber] setName:@"Fiber A"];
	int		i = 0;
	while( i < 100 )
	{
		NSAutoreleasePool	* pool = [[NSAutoreleasePool alloc] init];
		do
		{
			[TestClass autoreleaseTestClassWithName:[NSString stringWithFormat:@"A%d", i]];
			NSLog( @"method %s, iteration %d", _cmd, i );
			if( ![aNext isFinished] )
				[aNext continue];
			i++;
		}
		while( i%11 != 0 );
		[pool drain];
	}
}

+ (void)methodB:(NDFiber *)aNext
{
	[[NDFiber currentFiber] setName:@"Fiber B"];
	int		i = 0;
	while( i < 100 )
	{
		NSAutoreleasePool	* pool = [[NSAutoreleasePool alloc] init];
		do
		{
			[TestClass autoreleaseTestClassWithName:[NSString stringWithFormat:@"B%d", i]];
			NSLog( @"method %s, iteration %d", _cmd, i );
			if( ![aNext isFinished] )
				[aNext continue];
			i++;
		}
		while( i%17 != 0 );
		[pool drain];
	}
}

@end
