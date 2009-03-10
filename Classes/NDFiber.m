/*
	NDFiber.h class

	Created by Nathan Day on 02.02.09 under a MIT-style license. 
	Copyright (c) 2009 Nathan Day

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
 */

#include <limits.h>
#import "NDFiber.h"
#include <pthread.h>

NSString	* NDFiberWillExitNotification = @"NDFiberWillExit",
			* NDFiberSucceedToFinishedFiberException = @"NDFiberSucceedToFinishedFiber";

static const size_t		kMinStackSize = PTHREAD_STACK_MIN,
						kStackSizeBuffer = 0x4000;

@interface NDFiber (Private)
- (ucontext_t *)ucontext;
@end

@implementation NDFiber

static pthread_key_t	currentFiberKey,
						mainFiberKey;

static pthread_once_t	threadValuesInitKey = PTHREAD_ONCE_INIT;

static void threadValuesInitFunc()
{
    pthread_key_create(&currentFiberKey, NULL);
    pthread_key_create(&mainFiberKey, NULL);
}

static size_t _getDefaultStackSize(void)
{
	static size_t	theDefaultStackSize = 0;

	if( theDefaultStackSize == 0 )
	{
		pthread_attr_t		theThreadAttrs;        // Find out default pthread stack size
		int					theError = pthread_attr_init(&theThreadAttrs);
		if( !theError )
			theError = pthread_attr_getstacksize(&theThreadAttrs, &theDefaultStackSize);
		if( theError )
			theDefaultStackSize = 512*1024;
	}
	return theDefaultStackSize;
}

+ (NDFiber *)detachNewFiberSelector:(SEL)aSelector toTarget:(id)aTarget withObject:(id)anArgument
{
	NDFiber		* theFiber = [[[self alloc] initWithTarget:aTarget selector:aSelector object:anArgument] autorelease];
	[theFiber continue];
	return theFiber;
}

+ (NDFiber *)currentFiber
{
	NDFiber		* theFiber = nil;

	pthread_once( &threadValuesInitKey, threadValuesInitFunc );

    if( (theFiber = (NDFiber*)pthread_getspecific( currentFiberKey )) == nil )
	{
		theFiber = [NDFiber mainFiber];
        pthread_setspecific( currentFiberKey, (void*)theFiber);
	}
	return theFiber;
}

+ (NDFiber *)mainFiber
{
	NDFiber		* theFiber = nil;

	pthread_once( &threadValuesInitKey, threadValuesInitFunc );
	
    if( (theFiber = (NDFiber*)pthread_getspecific( mainFiberKey )) == nil)
	{
		theFiber = [[NDFiber alloc] init];
        pthread_setspecific( mainFiberKey, (void*)theFiber);
	}
	return theFiber;
}

+ (BOOL)isMainFiber
{
	return [self currentFiber] == [self mainFiber];
}

+ (void)yieldToFiber:(NDFiber *)aFiber
{
	[aFiber continue];
}

+ (id)fiberWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
{
	return [[[self alloc] initWithTarget:aTarget selector:aSelector object:anArgument] autorelease];
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
{
	NSParameterAssert( aTarget != nil );
	NSParameterAssert( aSelector != (SEL)0 );

	if( (self = [self init]) != nil )
	{
		entry.target = [aTarget retain];
		entry.selector = aSelector;
		entry.argument = [anArgument retain];
		stack.size = _getDefaultStackSize();
	}
	return self;
}

- (void)dealloc
{
	[fiberDictionary release];
	[name release];
	[entry.target release];
	[entry.argument release];
	[super dealloc];
}

- (NSMutableDictionary *)fiberDictionary
{
	if( fiberDictionary == nil )
		fiberDictionary = [[NSMutableDictionary alloc] init];
	return fiberDictionary;
}

- (void)continue
{
	if( isFinished )
	{
		NSString		* theName = [self name];
		[NSException raise:NDFiberSucceedToFinishedFiberException format:@"Attempted to continue finished fiber '%@'", theName ? theName : @"<unnamed>"];
	}

	NDFiber		* theCurrentFiber = [NDFiber currentFiber];
	if( self != theCurrentFiber )
	{
        pthread_setspecific( currentFiberKey, (void*)self);
		swapcontext( [theCurrentFiber ucontext], [self ucontext] );
	}
}

- (BOOL)isCurrentFiber
{
	return [NDFiber currentFiber] == self;
}

- (void)setName:(NSString *)aName
{
	name = [aName retain];
}
- (NSString *)name
{
	return name;
}

- (BOOL)isExecuting
{
	return stack.bytes != NULL && isFinished == NO;
}

- (BOOL)isFinished
{
	return isFinished;
}

- (BOOL)isMainFiber
{
	return [NDFiber mainFiber] == self;
}

- (NSUInteger)stackSize
{
	return stack.size;
}

- (void)setStackSize:(NSUInteger)aSize
{
	// round up to nearst multiple of 4Kb
	stack.size = ((aSize >> 12) + (aSize & 0xFFF) != 0) << 12;
}

@end

@implementation NDFiber (Private)

- (void)_entry
{
	[entry.target performSelector:entry.selector withObject:entry.argument];
	[[NSNotificationCenter defaultCenter] postNotificationName:NDFiberWillExitNotification object:self];
	isFinished = YES;
}

- (ucontext_t *)ucontext
{
	if( !stack.bytes && entry.target )
	{
		size_t		theStackSize = kMinStackSize;

		if( stack.size > kMinStackSize )
			theStackSize = stack.size;

		theStackSize += kStackSizeBuffer;

		stack.bytes = valloc(theStackSize);

		assert(stack.bytes);

		getcontext(&ucontext);

		ucontext.uc_stack.ss_sp = stack.bytes;
		ucontext.uc_stack.ss_size = theStackSize;
		ucontext.uc_stack.ss_flags = 0;
		ucontext.uc_link = [[NDFiber mainFiber] ucontext];

		makecontext( &ucontext, (void (*)(void))[self methodForSelector:@selector(_entry)], 2, self, @selector(_entry) );
	}
	return &ucontext;
}

@end