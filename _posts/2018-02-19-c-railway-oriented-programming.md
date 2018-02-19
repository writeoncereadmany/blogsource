---
layout: post
title: Railway-Oriented Programming
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the sixth in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. Previous parts:
 - [Most code fails badly](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly)
 - [How to fail in Java](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java)
 - [Carpet-oriented programming](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming)
 - [The difference between functions and methods](https://writeoncereadmany.github.io/2018/02/a-the-difference-between-functions-and-methods)
 - [The Applicable Pattern](https://writeoncereadmany.github.io/2018/02/b-pipe-dreams-or-the-applicable-pattern)

Before we start, I'd recommend at least reading [Carpet-oriented programming](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming).

So. We've got this concept of carpet-oriented programming - of building a pipeline
of operations which could fail, sweeping any failures under the carpet, and only
thinking about whether it succeeded or not (and what to do about failures) at the end.

One thing this approach lacks is any feedback as to *how*, or *why*, it failed.

<!--more-->

If we fail, we just get `Optional.empty()`. So instead of having a type which is
either a value (of an arbitrary type) or nothing, what if we have a type which
is either a success (of an arbitrary type) or a failure (of an arbitrary type)?

Let's update `MyOptional` to do that. Before:

```java
public abstract class MyOptional<T> {
  private MyOptional() {}
  public static <E> MyOptional<E> of(E value) { return new Present(value); }
  public static <E> MyOptional<E> empty() { return new Absent(); }
  public abstract <R> either(Function<T, R> whenPresent, Supplier<R> whenAbsent);
  public <R> R then(Function<T, R> function) { return function.apply(this); }

  private static class Present<T> extends MyOptional<T> {
    private final T value;
    public Present(T value) { this.value = value; }
    public <R> either(Function<T, R> whenPresent, Supplier<R> whenAbsent) {
      return whenPresent.apply(value);
    }
  }

  private static class Absent<T> extends MyOptional<T> {
    public <R> either(Function<T, R> whenPresent, Supplier<R> whenAbsent) {
      return whenAbsent.get();
    }
  }
}
```

After:

```java
public abstract class Result<S, F> {
  private MyOptional() {}
  public static <S, F> Result<S, F> success(S value) { return new Success(value); }
  public static <S, F> Result<S, F> failure(F value) { return new Failure(value); }
  public abstract <R> either(Function<S, R> onSuccess, Function<F, R> onFailure);
  public <R> R then(Function<T, R> function) { return function.apply(this); }

  private static class Success<S, F> extends Result<S, F> {
    private final S value;
    public Success(S value) { this.value = value; }
    public <R> either(Function<S, R> onSuccess, Function<F, R> onFailure) {
      return onSuccess.apply(value);
    }
  }

  private static class Failure<S, F> extends Result<S, F> {
    private final F value;
    public Failure(F value) { this.value = value; }
    public <R> either(Function<S, R> onSuccess, Function<F, R> onFailure) {
      return onFailure.apply(value);
    }
  }
}
```

All we've done is replace the non-value carrying `Absent` subtype with a generic
value-carrying `Failure` subtype, and update `either()` to take a `Function` in
both cases (instead of a `Supplier` for the absent case).

This means in order to construct a failing `Result`, we need to tell it *why* it failed.
Instead of:

```java
public class King {
  private final Beard beard;
  private final String name;
  ...
  public Optional<Beard> getBeard() {
    return Optional.ofNullable(beard);
  }
}
```

We could write:

```java
public class King {
  private final Beard beard;
  private final String name;
  ...
  public Result<Beard, String> getBeard() {
    if(this.beard != null) {
      return success(beard);
    } else {
      return failure(name + " does not have a beard");
    }
  }
}
```

### Building a pipeline

So, we have a single value which can represent either a success or a failure.
Now we can build variations of `map()`, `flatMap()` and `orElse()` for `Result`.

Instead of `map()`, we have `onSuccess()`, which will transform a value if it's
a success but leave failures untouched:

```java
public static <IS, OS, F> Function<Result<IS, F>, Result<OS, F>> onSuccess(
  Function<IS, OS> f)
{
  return result -> result.either(
    succ -> success(f.apply(succ)),
    fail -> failure(fail)
  );
}
```

Instead of `flatMap()`, we have `attempt()`, which transforms a success into either
a success or failure, but leaves failures untouched:

```java
public static <IS, OS, F> Function<Result<IS, F>, Result<OS, F>> attempt(
  Function<IS, Result<OS, F>> f)
{
  return result -> result.either(
    succ -> f.apply(succ),
    fail -> failure(fail)
  );
}
```

Instead of `orElse()`, we have `ifFailed()`, which resolves a `Result` into a
value by turning failure types into an instance of our desired, successful type:

```java
public static <S, F> Function<Result<S, F>, S> ifFailed(Function<F, S> resolver) {
  return result -> result.either(
    succ -> succ,
    fail -> resolver.apply(fail)
  );
}
```

### On naming things

Why all the renames? Don't `map()`, `flatMap()` and `orElse()` seem as appropriate to
`Result` as they do to `Optional`?

Well, this is partly a matter of personal taste: I don't think those names *are*
super appropriate in Java. It's different in Haskell, where you can meaningfully
abstract over *all* the things that have similar `map` methods - these things aren't
just conceptually similar, they're *polymorphically the same abstraction*. That's
not true here, so I'd rather give them more evocative names.

It's also a matter of what *else* we can do with `Result`s. I'll come to that
in a later post, though, because it's worth observing what we have here first.

### Putting it together

With this one simple change, we can now build pipelines which carry on happily
doing their own thing, putting failures to one side. Now, though, when they fail,
they convey information as to why, which we can handle at the end.

Which means, to hark back to the first post in the series, we can now see what's
going on here:

```java
public Response updateEmail(String requestBody) {
  return objectMapper.readValue(requestBody, EmailChangeRequest.class)
    .then(attempt(this::validateEmail))
    .then(onSuccess(Email::canonicalise))
    .then(attempt(req -> pair(accountRepository.get(req.id), req)))
    .then(onSuccess(pair -> pair.account.setEmail(pair.change.newEmail)))
    .then(attempt(accountRepository::update))
    .then(onSuccess(Response::ok))
    .then(ifFailed(reason -> Response.badRequest(reason)));
}
```

We're reading a value from a `String` into an `EmailChangeRequest`. That's
deserialisation - an operation which can fail - so we get a `Result<EmailChangeRequest, String>`, with a message in the failure case.
Then:
 - Validation can fail, so we need to attempt it.
 - Canonicalisation always works, so we can just do it.
 - Finding the account in the database can fail, so we need to attempt it.
 - Updating a record we have with an e-mail in-memory we have always works, so we can just do it.
 - Persisting that record back to the database can fail, so we need to attempt it.
 - Creating an OK response always works, so we do it
 - If any previous step has failed, that failure message will have cascaded through
 to the last line, and we can use it to build an appropriate response.

None of the methods like `validateEmail()`, `accountRepository.update()` and so on
need to care about a `Result` going in, or what the previous failure modes might be.
All they need to do is provide a `Result` themselves - and that's only if they
might fail. Methods like `Email::canonicalise` (which always succeed) don't need to know
anything about the `Result` context at all.

### Railway-Oriented Programming

This is often referred to as "Railway-Oriented programming" - visualising the
control flow as two train tracks, one of which carries successes and another
which carries failures.

Sometimes trains will hit a function on the success track which transforms them.
That won't affect trains on the failure track - they'll just trundle on by.
That's `onSuccess()`.

Sometimes trains will hit a function on the success track which could either
leave them on the success track, or route them to the failure track. Trains
on the failure track will also trundle by. That's `attempt()`.

And then sometimes we'll merge the tracks and just have values, instead of
results. That's `ifFailed()`.

And that's railway-oriented programming in a nutshell. It's a way to string
together a sequence of possibly-failing operations, marking the operations which
might fail, and deferring the need to handle failures to a single point.
And these three primary functions are all you need to know.

Now, that said, there's a whole lot more you *could* know, to do some much more
interesting and powerful stuff...
