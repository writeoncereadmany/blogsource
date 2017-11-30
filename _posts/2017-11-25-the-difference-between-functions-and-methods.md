---
layout: post
title: The Applicable Pattern, or The Difference Between Functions And Methods
author: Tom Johnson
published: false
excerpt_separator: <!--more-->
---

This is the fourth in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly),
a [critique of different ways to represent failure here](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java),
and [an overview of carpet-oriented programming - abstracting control flow with Optionals - here](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming).

Java 8 introduced `Optional`, along with lambdas and method references. There
was quite a lot of debate on its API - some wanted it to be just a null-safe
container, whereas others lobbied for methods like `map` and `flatMap`.

Getting the API right for foundational types like `Optional` is really hard. Too
many capabilities and the clarity of purpose is obscured; too few and you miss
opportunities for powerful constructs.

`Optional` got it wrong in both directions: it has methods it shouldn't, and it
doesn't have methods it should. This is a near-unavoidable consequence of a
fundamental design mistake: the API of `Optional` is made of methods instead
of functions.

<!--more-->

Let's start with the high-level capabilities it has but shouldn't, and should
have but doesn't:

1. Optional.get()

The *point* of `Optional` is that it may be empty, and it forces you to instruct
it on what to do instead when there's nothing there. If you want to fail, there's
the much clearer `Optional.orElseThrow()`.

The main reasons I see people using `Optional.get()` boil down to either not understanding
[how to effectively compose operations on Optional directly](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming)
or not respecting the possibility of an `Optional` being empty - ie, working
around safety.

This is a method which shouldn't be on `Optional`.

2. Optional.ifAbsent()

Sometimes, you want to perform a side-effecty action if there's something in an
`Optional`. For cases like that, there's `ifPresent()`:

```java
Optional<String> maybeName = Optional.of("Pietr");
maybeName.ifPresent(System.out::println);
```

Sometimes, you want to perform a side-effecty action if there's nothing in an
`Optional`. For example:

```java
Optional<String> maybeName = Optional.empty();
maybeName.ifAbsent(() -> LOGGER.warn("No name provided"));
```

The difference is: `ifPresent()` exists on the API, and `ifAbsent()` doesn't.
It's easy enough to provide our own:

```java
Optional<String> maybeName = Optional.empty();
ifAbsent(maybeName, () -> LOGGER.warn("No name provided"));

public <T> static void ifAbsent(Optional<T> maybe, Runnable task) {
  if(!maybe.isPresent()) { task.run(); };
}
```

But maybe we want both side-effects:
```java
Optional<String> maybeName = Optional.empty();
maybeName.ifPresent(System.out::println);
ifAbsent(maybeName, () -> LOGGER.warn("No name provided"));
```

The calling conventions for provided API methods and our own custom interactions
are different, which is annoying on a number of fronts. It disguises the
symmetry of the two tasks, it makes it clear that custom operations are
second-class citizens, we have auto-complete discoverability on API operations
but not ours so it's quite likely users will constantly restrict themselves to
the provided API, and so on.

It quickly became apparent that this was an important capability for `Optional`,
and it showed up in Java 9 as `Optional.ifPresentOrElse()`.

Maybe, you're thinking, that's just life: we can't expect API implementers to
anticipate every possible requirement. That's true. However, it's possible to
satisfy every possible operation on an `Optional` with just a single method,
`either`:

```java
public abstract class MyOptional<T> {
  private MyOptional() {}
  public static <E> MyOptional<E> of(E value) { return new Present(value); }
  public static <E> MyOptional<E> empty() { return new Absent(); }
  public abstract <R> either(Function<T, R> whenPresent, Supplier<R> whenAbsent);

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

Literally everything we could ever want to do with an `Optional`, we can do
with this. `map` is a one-liner:
```java
public static <T, R> map(MyOptional<T> maybe, Function<T, R> mapper) {
  return maybe.either(v -> MyOptional.of(mapper.apply(v)), MyOptional::empty);
}
```
As is `flatMap`:
```java
public static <T, R> flatMap(MyOptional<T> maybe, Function<T, Optional<R>> mapper) {
  return maybe.either(mapper, MyOptional::empty);
}
```
As is `orElse`:
```java
public static <T> orElse(MyOptional<T> maybe, T defaultValue) {
  return maybe.either(v -> v, () -> defaultValue);
}
```
As is our desired `ifAbsent`:
```java
public static Void ifAbsent(MyOptional<T> maybe, Runnable whenAbsent) {
  return maybe.either(v -> null, () -> { whenAbsent.run(); return null; });
}
```
And so on. By restricting ourselves to primitive operations like `either`, and
then implementing functions using it, we have an extensible approach which allows
end-users to add new functionality *with the same calling convention as the
shipped API*.

This isn't just a case of insurance against oversight in the initial API design:
it fundamentally supports a type of abstraction an API made of methods doesn't.
`ifAbsent` is the sort of thing you can argue ought to be a method on `Optional`,
but over time you'll find yourself wanting all sorts of different operations at
different levels of abstraction.

From the relatively generic and widespread - like safely casting to a subtype:
```java
public static <T, S extends T> MyOptional<S> castTo(T value, Class<S> subclass) {
  if(subclass.isAssignableFrom(value.getClass())) {
    return MyOptional.of((S) value);
  } else {
    return MyOptional.empty();
  }
}
```

To the highly domain-specific:
```java
public static Optional<Hat> getHat(Person person) {
  if(person.hasHat()) {
    return MyOptional.of(person.getHat());
  } else {
    return MyOptional.empty();
  }
}
```
