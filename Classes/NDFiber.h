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

/*!
	@header NDFiber
	@abstract Header file for the class NDFiber
	@version 1.0.0
 */
#import <Cocoa/Cocoa.h>
#include <ucontext.h>

/*!
	@const NDFiberWillExitNotification
	@discussion An <tt>NDFiber</tt> object posts this notification when it receives the exit message, before the thread exits. Observer methods invoked to receive this notification execute in the exiting thread, before it exits.
	The notification object is the exiting <tt>NDFiber</tt> object. This notification does not contain a userInfo dictionary.
	@version 1.0.0
 */
extern NSString		* NDFiberWillExitNotification;
/*!
	@const NDFiberSucceedToFinishedFiberException
	@discussion An <tt>NDFiber</tt> will throw this exception if you try yield to a fiber that has finished executing.
	@version 1.0.0
 */
extern NSString		* NDFiberSucceedToFinishedFiberException;

#define HAS_BROKEN_UCONTEXT

/*!
	@class NDFiber
	@abstract Fiber are co-operative multitasking threads.
	@discussion Unlike modern threads that depends on the kernel's thread scheduler to preempt a busy thread and resume another thread; fibers yield themselves to run another fiber while executing. Fibers are much easier to program than threads as by controlling when a fiber yields you can avoid race conditions, but this is at the expense of parallel execution on multiple cores. 
	@author Nathan Day
	@version 1.0.0
 */
@interface NDFiber : NSObject
{
@private
	ucontext_t			ucontext;
#if defined(__APPLE__) && defined(HAS_BROKEN_UCONTEXT)
	_STRUCT_MCONTEXT	__ucontext_padding;				// fix bug where header file describes a ucontext_t which smaller than actual implementation
#endif
	struct
	{
		size_t				size;
		void				* bytes;
	}					stack;
	struct
	{
		id					target;
		SEL					selector;
		id					argument;
	}					entry;
	BOOL				isFinished;
@protected
	NSMutableDictionary	* fiberDictionary;
	NSString			* name;
}

/*!
	@method detachNewFiberSelector:toTarget:withObject:
	@abstract Detaches a new fiber and uses the specified <tt><i>selector</i></tt> as the fiber entry point.
	@discussion For non garbage-collected applications, the method <tt><i>selector</i></tt> can set up an autorelease pool for the newly detached fiber and freeing that pool before it exits, but unlike threads this is not required. Also the fiber returned is autoreleased and so you need to retain it like you retain any other object.
 The objects aTarget and anArgument are retained during the execution of the detached fiber, then released. The detached fiber is exited as soon as aTarget has completed executing the aSelector method.
	@author Nathan Day
	@param selector The selector for the message to send to the target. This selector must take only one argument and must not have a return value.
	@param target The object that will receive the message aSelector on the new fiber.
	@param argument The single argument passed to the target. May be <tt>nil</tt>.
 */
+ (NDFiber *)detachNewFiberSelector:(SEL)selector toTarget:(id)target withObject:(id)argument;

/*!
	@method currentFiber
	@abstract Returns the fiber object representing the current fiber of execution.
	@result A fiber object representing the current fiber of execution.
	@author Nathan Day
 */
+ (NDFiber *)currentFiber;

/*!
	@method mainFiber
	@abstract Returns the <tt>NDFiber</tt> object representing the main fiber.
	@result The <tt>NDFiber</tt> object representing the main fiber.
	@author Nathan Day
 */
+ (NDFiber *)mainFiber;

/*!
	@method isMainFiber
	@abstract Returns a Boolean value that indicates whether the current fiber is the main fiber.
	@discussion Perfomrs a <tt>[NDFiber currentFiber] == [NDFiber mainFiber]</tt>.
	@result YES if the current fiber is the main fiber, otherwise NO.
	@author Nathan Day
 */
+ (BOOL)isMainFiber;

/*!
	@method yieldToFiber:
	@abstract Yields execution of current fiber to another fiber.
	@discussion sends a <tt>continue<tt> to the argument <tt><i>fiber</i></tt>. If the fiber <tt><i>fiber</i></tt> has finished then the exception <tt>NDFiberSucceedToFinishedFiberException</tt> is thrown
	@author Nathan Day
 */
+ (void)yieldToFiber:(NDFiber *)fiber;

/*!
	@method fiberWithTarget:selector:object:
	@abstract Returns an <tt>NDFiber</tt> object initialized with the given arguments.
	@discussion For non garbage-collected applications, the method aSelector can set up an autorelease pool for the newly detached fiber and freeing that pool before it exits, but unlike threads this is not required. Also the fiber returned is autoreleased and so you need to retain it like you retain any other object.
		The objects aTarget and anArgument are retained during the execution of the detached fiber, then released. The detached fiber is exited as soon as aTarget has completed executing the aSelector method.
	@author Nathan Day
	@param target The object to which the message specified by <tt><i>selector</i></tt> is sent.
	@param selector The selector for the message to send to target. This selector must take only one argument and must not have a return value.
	@param argument The single argument passed to the target. May be <tt>nil</tt>.
	@result An autoreleased <tt>NDFiber</tt> object initialized with the given arguments.
 */
+ (id)fiberWithTarget:(id)target selector:(SEL)selector object:(id)argument;
/*!
	@method initWithTarget:selector:object:
	@abstract Returns an <tt>NDFiber</tt> object initialized with the given arguments.
	@discussion For non garbage-collected applications, the method aSelector can set up an autorelease pool for the newly detached fiber and freeing that pool before it exits, but unlike threads this is not required.
		The objects aTarget and anArgument are retained during the execution of the detached fiber, then released. The detached fiber is exited as soon as aTarget has completed executing the aSelector method.
	@author Nathan Day
	@param target The object to which the message specified by <tt><i>selector</i></tt> is sent.
	@param selector The selector for the message to send to target. This selector must take only one argument and must not have a return value.
	@param argument The single argument passed to the target. May be <tt>nil</tt>.
	@result An <tt>NDFiber</tt> object initialized with the given arguments.
 */
- (id)initWithTarget:(id)target selector:(SEL)selector object:(id)argument;

/*!
	@method fiberDictionary
	@abstract Returns the fiber object's dictionary.
	@discussion You can use the returned dictionary to store fiber-specific data. The fiber dictionary is not used during any manipulations of the <tt>NDFiber</tt> object—it is simply a place where you can store any interesting data. You may define your own keys for the dictionary.
	@result The fiber object's dictionary.
	@author Nathan Day
 */
- (NSMutableDictionary *)fiberDictionary;

/*!
	@method continue
	@abstract yields the current fiber to the receiver
	@discussion This is the method in which the switching between fibers occurs, <tt>+[NDFiber yieldToFiber:]</tt> sends this message to its argument. If the receiver is finished then the exception <tt>NDFiberSucceedToFinishedFiberException</tt> is thrown
	@author Nathan Day
 */
- (void)continue;

/*!
	@method isCurrentFiber
	@abstract Tests if the fiber is the current fiber for the current thread
	@result Returns <tt>YES</tt> if the receiver is equal to <tt>+[NDFiber currentFiber]</tt> otherwise <tt>NO</tt>
	@author Nathan Day
 */
- (BOOL)isCurrentFiber;

/*!
	@method setName:
	@abstract Sets the name of the receiver.
	@param name The name for the receiver.
	@author Nathan Day
 */
- (void)setName:(NSString *)name;
/*!
	@method name
	@abstract Returns the name of the receiver.
	@result The name of the receiver.
	@author Nathan Day
 */
- (NSString *)name;

/*!
	@method isExecuting
	@abstract Returns a Boolean value that indicates whether the receiver is executing.
	@result YES if the receiver is executing, otherwise NO.
	@author Nathan Day
 */
- (BOOL)isExecuting;

/*!
	@method isFinished
	@abstract Returns a Boolean value that indicates whether the receiver has finished execution.
	@discussion Trying to <tt>continue</tt> or yeild to a finished fiber will throw an <tt>NDFiberSucceedToFinishedFiberException</tt> exception.
	@result YES if the receiver has finished execution, otherwise NO.
	@author Nathan Day
 */
- (BOOL)isFinished;

/*!
	@method isMainFiber
	@abstract Returns a Boolean value that indicates whether the current fiber is the main fiber.
	@discussion A <tt>NDFiber</tt> instance is created for you as soon an you call the class method mainFiber or when you start using any other fibers.
	@result YES if the current fiber is the main fiber, otherwise NO.
	@author Nathan Day
 */
- (BOOL)isMainFiber;
/*!
	@method stackSize
	@abstract eturns the stack size of the receiver.
	@result The stack size of the receiver.
	@author Nathan Day
 */
- (NSUInteger)stackSize;
/*!
	@method setStackSize:
	@abstract Sets the stack size of the receiver. This value will be rounded up to the nearest multiple of 4KB.
	@discussion You must call this method before starting your fiber. Setting the stack size after the fiber has started changes the attribute size (which is reflected by the stackSize method), but it does not affect the actual number of pages set aside for the fiber.
	@author Nathan Day
	@param size The stack size for the receiver.
 */
- (void)setStackSize:(NSUInteger)size;

@end
