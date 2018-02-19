---
layout: post
title: The Difference Between Functions And Methods
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

This is the fourth in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly),
a [critique of different ways to represent failure here](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java),
and [an overview of carpet-oriented programming - abstracting control flow with Optionals - here](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming).

Java 8 introduced `Optional`, along with lambdas and method references. There
was quite a lot of debate on its API - some wanted it to be just a null-safe
container, whereas others lobbied for methods like `map()` and `flatMap()`.

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

*By implementing an API with methods, you are closing it to extension*.

### Functions: An Alternative to Methods

Maybe, you're thinking, that's just life: we can't expect API implementers to
anticipate every possible requirement, and provide a method for each. Even if we
could, it wouldn't be desirable: there would be a big cost to learning how to
use such classes. That's true. However, it's possible to satisfy every possible
requirement on an `Optional` with just a single method - `either`:

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
with this. `map()` is a one-liner:
```java
public static <T, R> MyOptional<R> map(
  MyOptional<T> maybe, Function<T, R> mapper)
{
  return maybe.either(v -> MyOptional.of(mapper.apply(v)), MyOptional::empty);
}
```
As is `flatMap()`:
```java
public static <T, R> MyOptional<R> flatMap(
  MyOptional<T> maybe, Function<T, Optional<R>> mapper)
{
  return maybe.either(mapper, MyOptional::empty);
}
```
As is `orElse()`:
```java
public static <T> T orElse(MyOptional<T> maybe, T defaultValue) {
  return maybe.either(v -> v, () -> defaultValue);
}
```
As is our desired `ifAbsent()`:
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
`ifAbsent()` is the sort of thing you can argue ought to be a method on `Optional`,
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

### Functions for everybody?

Now, this isn't desirable for *every* class. But for sum types like `Optional`,
it's effectively presenting a pattern match - this code in Java:

```java
public static String getName(MyOptional<Person> maybePerson) {
    return maybePerson.either(
        person -> person.getName(),
        ()     -> "Unknown");
}
```
Is equivalent to this code in Haskell:

```haskell
getName :: Maybe Person -> String
getName person = case person of
    (Just person) -> nameOf person
    Nothing       -> "Unknown"
```

This is exposing the internals of the class: the opposite of encapsulation.
That's not what we were taught about how to do OO well!

Well, the thing is, `MyOptional` *isn't really an object*. It's data. We don't
want to *limit* how people interact with it - we just want to make sure that
all the cases are covered, and addresses with code which handles that case.

All the methods - `map()`, `flatMap()` and so on - are there as abstractions for
*convenience*, not necessity. They're common operations, as opposed to fundamental
primitives of interacting with the type.

This is in contrast to, say, a `BankAccount` class, where we definitely *do* want to
limit how the user interacts with the internal state of the object. We can limit
access with functions, of course, but the desire for extensibility isn't the same.

### Summing Up

When you have a simple data type, you don't care how users manipulate it, and
a number of higher-order interactions with it, consider using methods to expose
that state safely and implement the higher-order interactions using functions. It
keeps the data-type implementation small, and encourages extension by users.

There is an important caveat: just doing this alone can lead to unwieldly code.
There's a second part to implementing this well (in Java, anyway): the
Applicable Pattern, which I'll discuss in the next post.
