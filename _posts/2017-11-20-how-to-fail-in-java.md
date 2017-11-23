---
layout: post
title: How to Fail in Java
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the second in a series of posts about [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here]
(https://writeoncereadmany.github.io/2017/11/most-code-fails-badly).

The library all revolves around a single central concept: the `Result` class.
A large part of the reason to use `Result` is how it can be manipulated,
allowing error-handling to be separated from core logic. But before we get to
that, there's another important reason to use `Result`: it fills an important
gap in Java's API.

Namely, to represent the outcome of an operation which may fail.

This may seem like kind of a huge oversight, seeing as many operations can
potentially fail - there's definitely a *need* for a tool for that job. That's
not to say Java doesn't have ways of handling potential failure - it does, just
that they're all bad.

<!--more-->

Let's start with the low-hanging fruit.

## Returning null

```java
public Coat illGetMyCoat(CloakroomTicket ticket) {
  return coats.get(ticket);
}
```

Do I really need to talk about why null-as-failure is a bad idea? I could
requote the inventor of null:

> I call it my billion-dollar mistake… I couldn’t resist
the temptation to put in a null reference, simply because it was so easy to
implement. This has led to innumerable errors, vulnerabilities, and system
crashes, which have probably caused a billion dollars of pain and damage
in the last forty years.
– Tony Hoare, inventor of ALGOL W.

But it's pertinent to talk about why null-as-failure is bad, for comparison
purposes:

### 1: Nulls are insidious

Nulls can get anywhere. It's possible for any (ok, any non-primitive) variable
to actually be null. In order to have confidence that a value is non-null, you
need to make yourself comfortable not just with the functions you call but also
the functions *they* call, recursively.

### 2: Unhandled nulls manifest late

When you have a variable that's null, there's a good chance you'll pass it
around a fair bit before trying to do anything with it. When you do, you'll get
a `NullPointerException`, but the real problem isn't the accessing code, it's the
code which generated the null in the first place - which can be a long way away
from the problematic code.

### 3: Nulls carry no information

When you have a null, that represents a failure of some sort - maybe a failure to
find a suitable value, maybe a failure to initialise. But it's important to
recognise that failures *have* sorts: when something fails, you inevitably want
to know why. Null values do not carry that information.

Let's move on.

## Return codes

```java
Set<String> names = new HashSet<>();
boolean actuallyRemovedSomething = names.remove("Timmy");
```

Return codes aren't frequently used in Java, but they do exist. They're more
common as a pattern in Unix utilities. Using the return value of a function to
indicate success or failure opens up a whole world of possibilities.

The example above just returns a boolean, and Unix utilities return ints, but
in principle we don't have to restrict ourselves to such types. We can return
rich types with failure details, or highly domain-specific reports. There are
just two main problems with this approach:

### 1: It only works with naturally-void methods

You can only use the return type to indicate the success or failure of a method
when you're *not using it for anything else*. That means we can only apply this
approach when we're not interested in returning a value, but instead in the
side effects of the method.

### 2: It's easily ignored

It's super easy, when writing code like this:

```java
Set<String> names = new HashSet<>();
boolean actuallyRemovedSomething = names.remove("Timmy");
```

to instead do this:

```java
Set<String> names = new HashSet<>();
names.remove("Timmy");
```

It may be that the failure case doesn't need handling. That's often true when
removing items from a set - less so when persisting a new record to a
database.

This probably isn't an ideal approach unless we really, really don't care (in
general) whether the error is handled or not.

## Sentinel values

```java
String findName(String text, String name) {
  int index = text.indexOf(name);
  if(index == -1) {
    return "Text does not include name";
  } else {
    return "Text includes name starting at index " + index;
  }
}
```

In the above code, -1 is a sentinel value: it's part of the return type, but
it signifies failure instead of a location in a string. This approach has two
key problems:

### 1: Failures look like successes

When this code fails, it returns a value which can theoretically be used for
computation as if it were a success. If the caller isn't aware of the possibility
of failure, this could cause all sorts of interesting behaviour, which could be
just subtly wrong instead of blow-up-the-world type wrong.

### 2: Failures aren't richer

If I want to find out where in a string I can find a substring, an int is an
ideal type to represent that. If I've failed to find a substring, int isn't
particularly helpful. Sure, it's possible to map one type to another, but that's
an extra step which requires consulting the documentation, as opposed to being
self-describing.

## Multiple Return values

```go
response, err := ETPhoneHome("I can't fly this bike forever!")
if err != nil {
    // handle the error, often:
    return err
}
// do something with response
```

This isn't common in Java, but it's a standard pattern in Go. It's really
just syntactic sugar around returning a tuple and then destructuring it - we
could choose to implement it in Java with something like this:

```java
class Result {
  public final Response response;
  public final Failure err;

  public Result(Response response, Failure err) {
    this.response = response;
    this.err = err;
  }
}

result = ETPhoneHome("I can't fly this bike forever!")
if result.err != nil {
    // handle the error, often:
    return err
}
// do something with result.response
```

This solves some of the problems we had above:
 - It allows a rich type to our failure cases
 - The wrapping in a Result draws the programmer's attention to the possibility
 of failure

But we still have an issue where it's easy to neglect the failure case - here,
it would be sloppiness on the caller's part rather than an insufficiently clear
API, but it's permitted. And it's an approach which still requires the usual
boilerplate around explicit checks.

## Exceptions

Well, this is the elephant in the room. Exceptions are probably the most common
and de-facto default way of handling errors in Java. There's a lot that's good
about them:

 - They manifest immediately - none of the late manifestation of nulls
 - They can represent arbitrarily rich failure types, decoupled from success types
 - Handling is optional, but continuing past failure is impossible

But there are some important downsides too:

 - Handling is optional - exceptions can be ignored, leading to program crashes
 - They must be handled *locally*, in the code immediately surrounding the error-handling
 - They don't integrate with functional constructs like lambdas and streams well
 - They're expensive and heavyweight
 - They don't advertise themselves (we'll talk checked exceptions separately)
 - Exception handling requires clunky boilerplate

Optional handling can be a boon in cases where we really don't want to handle
an error - it represents being in a state where there is no sensible forward-
moving option. This is a good mechanism when the error-case is truly exceptional.

But when it's more standard, then there are issues: you can't easily defer
handling to another system, their sphere of influence (ie the code which needs
to be prepared to handle them) grows as you defer handling by layers, it's easy
to overlook the need to handle them, and handling them is expensive both in
terms of runtime performance and readability.

## Checked Exceptions

Checked exceptions are intriguing from a design perspective, because they exist
for a very good reason: you want to document (and enforce handling of) the errors
a user of a method should anticipate.

Or, to paraphrase, checked exceptions are exceptions for non-exceptional
circumstances. This trades off one weakness of runtime exceptions - the risk of
overlooking them - at the cost of virally propagating boilerplate requirements,
and a standard control mechanism using very expensive objects.

There is one other big problem with checked exceptions, and that's functional
programming. Runtime exceptions integrate poorly with functional programming
using lambdas and streams, but checked exceptions don't integrate with it at
all.

## Exceptions and streams

```java
public Response updateEmail(String requestBody) throws IOException {
    <body elided>
}

public Stream<Response> updateEmails(Stream<String> requestBodies) throws IOException {
   return requestBodies.map(this::updateEmail);
}
```

This is the sort of thing you might want to do using Java's streams: you have a
method for dealing with one of an object, and so you take a stream and you map
that method over it.

Only thing is: you can't do this. It won't compile.

```java
public Response updateEmail(String requestBody) throws IOException {
    <body elided>
}

public Stream<Response> updateEmails(Stream<String> requestBodies) "!!blue!!"throws IOException"!!end!!" {
   return requestBodies.map("!!pink!!"this::updateEmail"!!end!!");
}
```
```
>> Unhandled exception: java.io.IOException
```
So, it's telling us we have an unhandled exception in `this::updateEmail`, even
though we've declared our method as `throws IOException`?

Well, yes, because *it's not that method which throws*. We won't actually execute
`updateEmail` on out stream until we call a terminal method (eg, `toList()`),
and that happens outside the `updateEmails` method. This is where 
exception-handling having to be local to the *code* which throws, rather than
generating a *value*, really starts to hurt us.

If we're going to be using lambdas and streams, we can't really make that
interface with exception-throwing code. Which is a real problem, because many
Java libraries, including large swathes of the JDK itself, throw exceptions for
error-handling.

## Optional

Optional has often been introduced as "a better `null`", which is true - but it
massively understates its usefulness.

An `Optional<T>` represents a value which either contains a (guaranteed
non-null) `T`, or doesn't. So, conceptually, it represents the same data as a
nullable value. The difference comes in how you interact with it.
