---
layout: post
title: Pipe Dreams, or - The Applicable Pattern
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the fifth in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly),
a [critique of different ways to represent failure here](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java),
an [an overview of carpet-oriented programming - abstracting control flow with Optionals - here](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming),
and [an argument for implementing rich behaviour on datatypes using standalone
functions instead of methods here](https://writeoncereadmany.github.io/2018/02/a-the-difference-between-functions-and-methods).

So. You're on board with using functions instead of methods, and you start applying
that approach. Most likely, you'll find that your code is bitty and clunky - it
just doesn't flow like it did when you were happily chaining methods.

Let's explore that.

### Functions? More like clunk-tions!

Using functions instead of methods looks fine in isolation, but the moment
you want to do something more complex - like building a carpet-oriented programming
pipe - the functional approach starts to get much harder to read.

<!--more-->

Let's take the example of the King of Spain's Beard from the previous article:

```java
public String describeKingsBeard(Country country) {
  Optional<Person> king = country.getMonarch();
  Optional<Beard> beard = king.flatMap(Person::getBeard);
  Optional<Color> beardColour = beard.map(Beard::getColour);
  Optional<String> message = beardColour.map(colour ->
    String.format("The king of %s has a %s beard", country, colour.describe()));
  return message.orElse(country + " does not have a bearded monarch");
}
```

We can rewrite that using `MyOptional` and functions instead of methods:

```java
public String describeKingsBeard(Country country) {
  MyOptional<Person> king = country.getMonarch();
  MyOptional<Beard> beard = flatMap(king, Person::getBeard);
  MyOptional<Color> beardColour = map(beard, Beard::getColour);
  MyOptional<String> message = map(beardColour, colour ->
    String.format("The king of %s has a %s beard", country, colour.describe()));
  return orElse(message, country + " does not have a bearded monarch");
}
```

And at this point, there's not a lot to argue between the two in terms of
readability and conciseness.

However! We don't leave code like this! We can clean up the code by inlining
all these interstitial variables:

```java
public String describeKingsBeard(Country country) {
  return country.getMonarch()
      .flatMap(Person::getBeard)
      .map(Beard::getColour)
      .map(colour -> String.format("The king of %s has a %s beard",
                                   country,
                                   colour.describe()))
      .orElse(country + " does not have a bearded monarch");
}
```

But when we try to do that to our functional approach:

```java
public String describeKingsBeard(Country country) {
  return orElse(
           map(
             map(
               flatMap(
                 country.getMonarch(),
                 Person::getBeard),
               Beard::getColour),
             colour -> String.format("The king of %s has a %s beard",
                                     country,
                                     colour.describe())),
           country + " does not have a bearded monarch");
}
```

You what?

The problem here is that every time we inline, instead of building a sequence
of operations, we're nesting our calls. More clearly - this code:

```java
public static D getD(A a) {
  B b = a.b();
  C c = b.c();
  D d = c.d();
  return d;
}
```

inlines to:

```java
public static D getD(A a) {
  return a.b().c().d();
}
```

Whereas this:

```java
public static D getD(A a) {
  B b = b(a);
  C c = c(b);
  D d = d(c);
  return d;
}
```

inlines to:

```java
public static D getD(A a) {
  return d(c(b(a)));
}
```

The problem here is that method calls are *infix*, whereas functions are *prefix*.
We can fix that, by introducing a function-infixing operation.

Now, we're working in Java here, so our tools are limited: that's fine, we can
do this with methods.

```java
public abstract class MyOptional<T> {
  private MyOptional() {}
  public static <E> MyOptional<E> of(E value) { return new Present(value); }
  public static <E> MyOptional<E> empty() { return new Absent(); }
  public abstract <R> either(Function<T, R> whenPresent, Supplier<R> whenAbsent);

  "!!blue!!"public <R> R then(Function<T, R> function) { return function.apply(this); }"!!end!!"

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

All we've done is add a method, which takes a function and applies the function
to the object. This means that instead of passing the object into the function,
we can pass the function into the object. As it happens, this is done in a
chainable way.

This does mean we need to rewrite our methods as higher-order functions: for
example, `map()` goes from this:

```java
public static <T, R> MyOptional<R> map(MyOptional<T> maybe, Function<T, R> mapper) {
  return maybe.either(v -> MyOptional.of(mapper.apply(v)), MyOptional::empty);
}
```

to this:

```java
public static <T, R> Function<MyOptional<T>, MyOptional<R>> map(Function<T, R> mapper) {
  return maybe -> maybe.either(v -> MyOptional.of(mapper.apply(v)), MyOptional::empty);
}
```

But then it allows us to rewrite our code as follows:

```java
public String describeKingsBeard(Country country) {
  MyOptional<Person> king = country.getMonarch();
  MyOptional<Beard> beard = king.then(flatMap(Person::getBeard));
  MyOptional<Color> beardColour = beard.then(map(Beard::getColour));
  MyOptional<String> message = beardColour.then(map(colour ->
    String.format("The king of %s has a %s beard", country, colour.describe())));
  return message.then(orElse(country + " does not have a bearded monarch"));
}
```

Which then inlines to this:

```java
public String describeKingsBeard(Country country) {
  return country.getMonarch()
      .then(flatMap(Person::getBeard))
      .then(map(Beard::getColour))
      .then(map(colour -> String.format("The king of %s has a %s beard",
                                        country,
                                        colour.describe())))
      .then(orElse(country + " does not have a bearded monarch"));
}
```

Which is a *little* more verbose than the traditional method-chaining approach,
but not that makes a big difference:

```java
public String describeKingsBeard(Country country) {
  return country.getMonarch()
      .flatMap(Person::getBeard)
      .map(Beard::getColour)
      .map(colour -> String.format("The king of %s has a %s beard",
                                   country,
                                   colour.describe()))
      .orElse(country + " does not have a bearded monarch");
}
```

It's certainly a darn sight better than trying to use functions *without* the
`then()` method.

### Functions are everywhere!

It turns out that building an API out of higher-order functions is useful,
as there are a bunch of other places in modern Java where you'd want to use them.
For example: streams. If we stop binding over the country in the example above:

```java
public String describeKingsBeard(Country country) {
  return country.getMonarch()
      .then(flatMap(Person::getBeard))
      .then(map(Beard::getColour))
      .then(map(colour -> String.format("Found a king with a %s beard",
                                        colour.describe())))
      .then(orElse("Found a country which does not have a bearded monarch"));
}
```

Then it's easy to modify the method to take a `Stream<Country>`:

```java
public Stream<String> describeKingsBeard(Stream<Country> countries) {
  return countries.map(Country::getMonarch)
      .map(flatMap(Person::getBeard))
      .map(map(Beard::getColour))
      .map(map(colour -> String.format("Found a king with a %s beard",
                                        colour.describe())))
      .map(orElse("Found a country without a bearded monarch"));
}
```

We just replace `then()` with `map()`, and it works in-place. We can't do that so
easily with our method-chained example - we can turn our calls into lambdas:

```java
public Stream<String> describeKingsBeard(Stream<Country> countries) {
  return countries.map(Country::getMonarch)
      .map(monarch -> monarch.flatMap(Person::getBeard))
      .map(beard -> beard.map(Beard::getColour))
      .map(bc -> bc.map(colour -> String.format("Found a king with a %s beard",
                                                colour.describe())))
      .map(message -> message.orElse("Found a country without a bearded monarch"));
}
```

Or we can nest the whole chain approach:

```java
public Stream<String> describeKingsBeard(Stream<Country> countries) {
  return countries.map(country -> country.getMonarch()
        .flatMap(Person::getBeard)
        .map(Beard::getColour)
        .map(colour -> String.format("The king of %s has a %s beard",
                                     country,
                                     colour.describe()))
        .orElse(country + " does not have a bearded monarch")
  );
}
```

Or we could extract it and deal with it separately:

```java
public Stream<String> describeKingsBeard(Stream<Country> countries) {
  return countries.map(this::describeKingsBeard);
}

public String describeKingsBeard(Country country) {
  return country.getMonarch()
      .then(flatMap(Person::getBeard))
      .then(map(Beard::getColour))
      .then(map(colour -> String.format("Found a king with a %s beard",
                                        colour.describe())))
      .then(orElse("Found a country which does not have a bearded monarch"));
}
```

Now, you may argue that none of these are that bad. The point is: you have to
stop and think about how to make this work in the context of a `Stream`, whereas
with the functional approach you're already thinking in terms of the higher-order
functions that a `Stream` needs.

### Universal Piping

There's another approach that could be taken here: instead of putting a `then()`
method on classes, we could just create a wrapper with a `then()` method:

```java
public class Piper<T> {
  private final T element;

  public Piper<>(T element) { this.element = element; }

  public <R> Piper<R> then(Function<T, R> f) {
    return new Piper<>(f.apply(element));
  }

  public T resolve() { return element; }
}
```

This does mean we need to wrap and unwrap the objects at each end of a chain.
But this provides a very important function: it allows us to chain custom operations
on arbitrary objects. That's useful when wanting to chain on types you don't control,
but it turns out to be pretty much essential for generic programming: this will
become apparent once we get into railway-oriented programming with `Result`.

Speaking of which: maybe it's time to move on from carpet-oriented programming to
the good stuff.
