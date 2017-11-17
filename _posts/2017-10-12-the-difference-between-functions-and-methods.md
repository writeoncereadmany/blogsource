---
layout: post
title: The Applicable Pattern
author: Tom Johnson
published: false
excerpt_separator: <!--more-->
---
### or, The Difference Between Functions and Methods

I'm not a huge fan of the API of `java.util.Optional`. I could list some
specific issues, but at the heart of it is one fundamental issue.

Namely: they made the API out of methods. For a data structure like
`Optional`, that's just a plain bad idea.

<!--more-->

That raises two obvious questions:
 - What's wrong with methods?
 - What's the alternative?

### What's Wrong with Methods

Methods are a great way of constraining your interface to the fundamental
operations on an object. The problem arises when you make the wrong decisions
about how to constrain these things. This is particularly important from the
perspective of an API developer.

There are two classes of mistake to be made here: not providing enough
functionality, and providing inappropriate functionality.

For example, `Optional` provides an `ifPresent()` method, but doesn't provide
`ifAbsent()`. It's easy enough to write one:

```java
public static void ifAbsent(Optional<?> maybe, Runnable task) {
  if (!maybe.isPresent()) { task.run(); }
}

public void commitCarrot(Optional<Carrot> maybeCarrot) {
  maybeCarrot.ifPresent(dao::commit);
  ifAbsent(maybeCarrot, () -> LOG.warn("Didn't get a carrot"));
}
```

There are a number of problems with this:
 - We need to write this, either bringing in another dependency or
 continually re-implementing it
 - The usage is inconsistent with that of `ifPresent()`, obfuscating the pattern.

So we could do something like this:
```java
public static <T> void ifPresent(Optional<T> maybe, Consumer<T> task) {
  maybe.ifPresent(task);
}

public static void ifAbsent(Optional<?> maybe, Runnable task) {
  if (!maybe.isPresent()) { task.run(); }
}

public void commitCarrot(Optional<Carrot> maybeCarrot) {
  ifPresent(maybeCarrot, dao::commit);
  ifAbsent(maybeCarrot, () -> LOG.warn("Didn't get a carrot"));
}
```

But then we're providing a non-idimatic replacement the library implementation,
in order for our code to be consistent. This doesn't seem to be a good habit to
get into.

It's worth noting that this example is now kinda out-of-date - Java 9 now allows:
```java
public void commitCarrot(Optional<Carrot> maybeCarrot) {
  maybeCarrot.ifPresentOrElse(
    dao::commit,
    () -> LOG.warn("Didn't get a carrot")
  );
}
```
This supports my point: it's an acknowledgement that the original `Optional`
interface was incomplete. Indeed, it's still not ideal - I still want `ifAbsent()`
on occasion, even if I can emulate it using `ifPresentOrElse()`. For example:
```java
public List<Vegetable> getVegetables() {
  List<Optional> veggies = asList(
    Optional.of(CARROT),
    Optional.empty(),
    Optional.of(BROCCOLI)
  );

  return veggies
    .stream()
    .peek(x -> x.ifAbsent(() -> LOG.info("No veggies!")))
    .flatMap(Optional::stream)
    .collect(toList());
}
```
Here, having to provide an action for when things are present would make the code
more complex, and disguise intentions.

Maybe the conclusion you might be drawing here is: well, you can't cater for
every possible need. I disagree - you can, and the way you do that is by _not
constraining the operations on types_. That can be done by instead building an
API out of functions.

### Functions: the Alternative to Methods

The irony is that it's possible to do everything anyone could ever possibly
want to do with an `Optional` with just one method. For example, we could choose
to implement it as follows (eliding all the usual Java `equals()` and so on
nonsense):

```java
public abstract class Optional<T> {
  private Optional() {}

  public abstract <R> R either(
    Function<T, R> whenPresent,
    Supplier<R> whenAbsent
  );

  public static class Present<T> extends Optional<T> {
    private final T element;

    public Present(T element) {
      this.element = element;
    }

    public <R> R either(
      Function<T, R> whenPresent,
      Supplier<R> whenAbsent
    ) {
      return whenPresent.apply(element);
    }
  }

  public static class Absent<T> extends Optional<T> {
    public <R> R either(
      Function<T, R> whenPresent,
      Supplier<R> whenAbsent
    ) {
      return whenAbsent.get();
    }
  }
}
```
By the way, `either()` here is a fold over `Optional`. It's possible to define
a fold over any algebraic datatype. The important point is: we can implement
every conceivable operation on `Optional` using it.

For example, implementing some of the methods from `java.util.Optional`:
```java
public static <T, R> Optional<R> map(
  Optional<T> maybe, Function<T, R> f
) {
  return maybe.either(
    val -> new Present(f.apply(val)),
    () -> new Absent()
  );
}

public static <T, R> Optional<R> flatMap(
  Optional<T> maybe, Function<T, Optional<R>> f
) {
  return maybe.either(
    val -> f.apply(val),
    () -> new Absent()
  );
}

public static <T, R> R get (Optional<T> maybe) {
  return maybe.either(
    val -> val,
    () -> { throw new BadAtProgrammingException(); }
  )
}
```
And so on.

The advantage of this is it allows us to extend the API with our own functions,
and use of those functions is nicely idiomatic:

```java
example code
```
And, for comparison, the same code with `java.util.Optional`:
```java
example code
```
Of course, nobody would write code and leave it like that. There's a ton of
unnecessary variable declarations we can inline. So, let's do that:
```java
horribly nested code
```
Oh. Oh dear. That's not nice at all. Whereas when we compare to `java.util.Optional`:
```java
nicely sequenced code
```
So, we can nicely logically sequence operations by chaining methods, but we
can't chain functions in the same way, and the prefix notation means they're
specified in reverse order. That's kind of a pain in the ass.

This isn't necessarily so, of course. For example, Elixir supports nice chaining
of function calls using the pipe operator:
```elixir
```
So. Maybe we can just do that in Java?

### The Applicable Pattern
