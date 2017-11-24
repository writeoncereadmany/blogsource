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
`Optional`. And we'll do this by investigating the case of the King of France's
beard.

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

*No. Bad programmer, no twinkie.* That is not how to use `Optional`.

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
