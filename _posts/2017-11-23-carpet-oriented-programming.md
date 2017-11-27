---
layout: post
title: Carpet-Oriented Programming
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the third in a series of posts about [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly), and
a [critique of different ways to represent failure here](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java).

Before we look at railway-oriented programming with `Result`, it'll help if we
start with the similar, but simpler case of carpet-oriented programming with
`Optional`. And we'll illustrate this with the King of Spain's Beard.

<!--more-->

### The King of Spain's Beard

So we want to know the colour of the King of Spain's beard, for reasons too
obvious to go into. Disregarding error handling, we might write something like
this:

```java
public String describeKingsBeard(Country country) {
  Person king = country.getMonarch();
  Beard beard = king.getBeard();
  Color beardColour = beard.getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```

The problems here are twofold:
 - The country may not have a monarch
 - If it does, the monarch may not have a beard
 - That said: if they do have a beard, it will have a describable colour

So we could represent this by returning null from the respective methods,
and then checking for it before proceeding:

```java
public String describeKingsBeard(Country country) {
  Person king = country.getMonarch();
  if(king == null) {
    return String.format("%s does not have a monarch", country);
  }
  Beard beard = king.getBeard();
  if(beard == null) {
    return String.format("%s does not have a beard", king);
  }
  Color beardColour = beard.getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```

Ugh, look at all that null-handling. We're using Java 8, we could use
`Optional` instead!

```java
public String describeKingsBeard(Country country) {
  Optional<Person> king = country.getMonarch();
  if(!king.isPresent()) {
    return String.format("%s does not have a monarch", country);
  }
  Optional<Beard> beard = king.get().getBeard();
  if(!beard.isPresent()) {
    return String.format("%s does not have a beard", king);
  }
  Color beardColour = beard.get().getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```

*No. Bad programmer, no twinkie.* That is **not** how to use `Optional`.

### Look ma, no ifs!

It's common to want to perform operations on `Optional` values - so common that
there's a handy method to help you do that without having to check for presence,
getting the value out, and then manipulating it. It's called `map()`:

```java
Optional<Beard> maybeBeard = Optional.of(new Goatee());
Optional<Color> beardColour = maybeBeard.map(Beard::getColour);
```
This will return a new `Optional` containing the result of the operation on the
value, if it was present, or an empty `Optional` if the original was empty.

`map()` *encapsulates the conditional*.

This is all well and good, but it's not quite enough. Sometimes, the method you
want to map over can fail - it returns an `Optional` itself. Mapping over it
would give us this:

```java
Optional<Person> maybePerson = Optional.of(queenElizabeth2);
Optional<Optional<Beard>> maybeBeard = maybePerson.map(Person::getBeard);
```

An `Optional` of an `Optional`, huh? We'd really like just a regular `Optional`:
 - if `maybePerson` is empty, we want an empty `Optional` at the end
 - if `maybePerson` is present, but has no beard, we want an empty `Optional`
 - if `maybePerson` is present and bearded, we want an `Optional` of that beard

Rather than nested `Optional`s, we'd prefer to flatten them into a single
`Optional`. Fortunately, there's something which will conveniently map and then
flatten for us - `flatMap()`:

```java
Optional<Person> maybePerson = Optional.of(queenElizabeth2);
Optional<Beard> maybeBeard = maybePerson.flatMap(Person::getBeard);
```

As a rule of thumb: use `flatMap` when an operation might fail, and `map` when
it won't.

So let's apply that to our whole method:

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
Now, I've written that all out so you can see the types, but in general I find
it's more readable if you just inline everything:

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

This is a model I like to call **Carpet-oriented Programming**.

### Carpet-Oriented Programming

The key concept of carpet-oriented programming is: you set up a sequence of
operations, assuming everything works. Then you run through the operations, and
if any of them fail, you just... sweep it under the carpet, carry on, and trust
you'll deal with it later.

For example, let's track the progression of values in a successful case - Spain:

```java
public String describeKingsBeard(Country country) {                 // country = Spain
  return country.getMonarch()                                       // gets Felipe VI
      .flatMap(Person::getBeard)                                    // neatly trimmed
      .map(Beard::getColour)                                        // salt & pepper
      .map(colour -> String.format("The king of %s has a %s beard", // describe it, and...
                                   country,
                                   colour.describe()))
      .orElse(country + " does not have a bearded monarch");        // n/m, we succeeded
}
```

And then contrast it with one failure case - England, which has a monarch without a beard:

```java
public String describeKingsBeard(Country country) {                 // country = England
  return country.getMonarch()                                       // gets Elizabeth II
      .flatMap(Person::getBeard)                                    // no. sweep under the carpet
      .map(Beard::getColour)                                        // nothing to see here
      .map(colour -> String.format("The king of %s has a %s beard", // still nope
                                   country,
                                   colour.describe()))
      .orElse(country + " does not have a bearded monarch");        // ...ok, i pick else
}
```

And another - France, which has no monarch:

```java
public String describeKingsBeard(Country country) {                 // country = France
  return country.getMonarch()                                       // vive la revolution: carpet
      .flatMap(Person::getBeard)                                    // le non
      .map(Beard::getColour)                                        // ceci n'est pas un beard
      .map(colour -> String.format("The king of %s has a %s beard", // je ne sais pas
                                   country,
                                   colour.describe()))
      .orElse(country + " does not have a bearded monarch");        // ...l'autre
}
```

We don't let worries about failure bother us. Rather than have our error
handling constantly interrupt our train of thought...

```java
public String describeKingsBeard(Country country) {
  Person king = country.getMonarch();
  "!!pink!!"if(king == null) {
    return String.format("%s does not have a monarch", country);
  }"!!end!!"
  Beard beard = king.getBeard();
  "!!pink!!"if(beard == null) {
    return String.format("%s does not have a beard", king);
  }"!!end!!"
  Color beardColour = beard.getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```

...we put all those concerns to one side, until we resolve a final result:

```java
public String describeKingsBeard(Country country) {
  return country.getMonarch()
      "!!pink!!".flatMap"!!end!!"(Person::getBeard)
      "!!pink!!".map"!!end!!"(Beard::getColour)
      "!!pink!!".map"!!end!!"(colour -> String.format("The king of %s has a %s beard",
                                   country,
                                   colour.describe()))
      "!!pink!!".orElse(country + " does not have a bearded monarch");"!!end!!"
}
```

This gives us something simpler, something easier to read.

It's not a perfect solution. In doing so, we've lost any detail to our failures.
We can't distinguish a failure because the country has no monarch from one where
the monarch is unbearded, as an empty `Optional` carries no information.

But now we understand the basic principles of abstracting and encapsulating
control flow, we can adapt it to `Result`, support both success and failure
details, and move from carpet-oriented to railway-oriented programming.

Before we do that, though, I first want to talk a little about the difference
between methods and functions.
