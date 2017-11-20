---
layout: post
title: How to Fail in Java
author: Tom Johnson
published: false
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
the functions they call, recursively.

### 2: Unhandled nulls manifest late

When you have a variable that's null, there's a good chance you'll pass it
around a fair bit before trying to do anything with it. When you do, you'll get
a `NullPointerException`, but the real problem isn't the accessing code, it's the
code which generated the null in the first place - which is a long way away from
the problematic code.

### 3: Nulls carry no information

When you have a null, that represents a failure of some sort - maybe a failure to
find a suitable value, maybe a failure to initialise. But it's important to
recognise that failures *have* sorts: when something fails, you inevitably want
to know why. Null values do not carry that information.

Let's move on.

## Return codes
