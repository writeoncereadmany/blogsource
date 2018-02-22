---
layout: post
title: Fancy Railways
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

This is the eighth in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. Previous parts:
 - [Most code fails badly](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly)
 - [How to fail in Java](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java)
 - [Carpet-oriented programming](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming)
 - [The difference between functions and methods](https://writeoncereadmany.github.io/2018/02/a-the-difference-between-functions-and-methods)
 - [The Applicable Pattern](https://writeoncereadmany.github.io/2018/02/b-pipe-dreams-or-the-applicable-pattern)
 - [Railway-Oriented Programming](https://writeoncereadmany.github.io/2018/02/c-railway-oriented-programming)
 - [What about the rest of the world?](https://writeoncereadmany.github.io/2018/02/d-what-about-the-rest-of-the-world)

Let's recap briefly. We now understand what railway-oriented programming is,
and we're comfortable abstracting over the idea of collating failures at different
points in an execution and handling them separately. We can combine operations
which always succeed and operations which may fail, we can convert pretty much
any failure mode into results, and we can resolve back to a regular value.

What else could we ask for? Well, let's take an example: we're working at the
gate of a ride at WonderFunLand. We've got a queue of people coming up to ride
the BoneRattler. Can they ride?

<!--more-->

```java
public Stream<Result<Person, NoRideReason>> admitToBoneRattler(Stream<Person> visitors) {
  return visitors
      .map(mustBeAtLeastHeight(120))
      .map(attempt(mustNotBePregnant()))
      .map(attempt(mustNotBeBannedForMooningRidePhoto()));
}
```

So far so good. Only now there's a new requirement: none of these apply if they're
the boss's kids. Yep, even the rules about height and pregnancy - for the sake
of narrative, we're submitting to implementing bad requirements.

#### Recovering from (some) failures

We *could* modify each condition to have the exception, but that would require
implementing it in three places. It would be much cleaner if we could just find those
exceptional cases, and make them successes again:

```java
public static <S,F> Function<Result<S, F>, Result<S, F>> recover(Function<F, Result<S, F> f) {
  return result -> result.either(
    succ -> success(succ), // if there's a success, pass it through
    fail -> f.apply(fail)  // if it was a failure, apply the function, which may return a success
  );
}
```

Let's say `NoRideReason` contains a reference to the `Person` for detail
messages, so it's easy to convert it back if need be:

```java
public Stream<Result<Person, NoRideReason>> admitToBoneRattler(Stream<Person> visitors) {
  return visitors
      .map(mustBeAtLeastHeight(120))
      .map(attempt(mustNotBePregnant()))
      .map(attempt(mustNotBeBannedForMooningRidePhoto()))
      "!!pink!!".map(recover(allowOnIfBossesKid()));"!!end!!"
}
```

Okay! That's great! Then a new request comes through: visitors are getting annoyed
by being turned away at the gate after queueing for an hour, so whenever we turn
someone away we're giving them a fast-track ticket to jump the line at
SplishySplashyCanyon.


#### Applying a side effect to one track of the railway

This is a mutable update on Person, so we just need to apply a side-effect to the failures:

```java
public static <S, F> Function<Result<S, F>, Result<S, F>> onFailureDo(Consumer<F> c) {
  return result -> result.either(
    succ -> success(succ),
    fail -> failure(peek(c).apply(fail))
  );
}

public static <T> Function<T, T> peek(Consumer<T> consumer) {
  return value -> {
    consumer.accept(value);
    return value;
  }
}
```

We're using `peek()` here, which turns a `void`-returning `Consumer` into a
`Function` which applies the consumer, then returns its input value. This is a
useful little utility function that crops up quite a lot when you want to apply
side-effects in pipelines. That's being used to implement `onFailureDo`, which
applies a side-effect to just failures. That lets us do this:

```java
public Stream<Result<Person, NoRideReason>> admitToBoneRattler(Stream<Person> visitors) {
  return visitors
      .map(mustBeAtLeastHeight(120))
      .map(attempt(mustNotBePregnant()))
      .map(attempt(mustNotBeBannedForMooningRidePhoto()))
      .map(recover(allowOnIfBossesKid()))
      "!!pink!!".map(onFailureDo(giveSplishySplashyCanyonGoldenTicket()));"!!end!!"
}
```

And then, of course, we only let the people who meet all our criteria onto the
ride.

#### Discarding failures

One approach could be to filter the stream to just the successes, and then get
the successes out - but the type system doesn't know that a filtered `Result`
is a success, so we'd still have to say what to do in the case a failure gets
through the filter.

There's a cleaner way, by flatmapping a stream. We can turn each
`Result<Person, NoRideReason>` into a `Stream<Person>`, and `Stream.flatMap()`
can concatenate all the streams together. A success contains one successful
`Person`, and a failure contains no successful `Person`s:

```java
public <S, F> Function<Result<S, F>, Stream<S>> successes() {
  return result -> result.either(
    succ -> Stream.of(succ),
    fail -> Stream.empty()
  )
}
```

Which then permits us to add:

```java
public Stream<Person> admitToBoneRattler(Stream<Person> visitors) {
  return visitors
      .map(mustBeAtLeastHeight(120))
      .map(attempt(mustNotBePregnant()))
      .map(attempt(mustNotBeBannedForMooningRidePhoto()))
      .map(recover(allowOnIfBossesKid()))
      .map(onFailureDo(giveSplishySplashyCanyonGoldenTicket()))
      "!!pink!!".flatMap(successes());"!!end!!"
}
```

#### This is just the beginning

These are examples of some of the utility functions available on `Result` which
allow you to build more versatile pipelines. They're all [in the control library](https://github.com/unruly/control), along with a bunch of other commonly
used constructs.

The philosophy here isn't "here's your set of tools - now go build stuff
with them", though. Sometimes, you'll want to operate on `Result`s in a novel
way. That's fine! That's good.

These functions are mostly very short and easy to write. Just write another.
