---
layout: post
title: Optionals, and other options
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

So I was recently talking about how much better than `null` `Optional` is, and the importance of using it correctly in order to get the most out of what they offer over `null`.

What I didn't talk about, though, was why you'd use either in the first place. Turns out that when you look at that, with a critical eye, `Optional` doesn't *entirely* solve the problem we have.

Let's take the example of the King of Spain's beard.

### The King of Spain's Beard

![King Phillip 2 of Spain](http://study.com/cimages/multimages/16/philip_ii_of_spain_by_antonio_moro.jpg)

What's the colour of the King of Spain's beard? From the image above, I'd describe it as... brown? Let's take a look at what some code to do that might look like:

```java
public static String getKingBeardColor(Country country) {
    King king = country.getKing();
    Beard beard = king.getBeard();
    String color = beard.getColor(); 
    return color;
}
```

Simple enough. Yeah, we could inline some stuff here, but I'm leaving types for clarity here. 

We run this method on our test data, and we do indeed get back `"Brown"`. So we deploy to production, and we're getting null pointer exceptions. What's going on here?

Turns out, Phillip 2 isn't the King of Spain anymore. This is the King of Spain:

![King Felipe VI of Spain](https://s-media-cache-ak0.pinimg.com/564x/7d/45/40/7d4540ab8158cad10c70d396ed41572b.jpg)

The problem here, in case it wasn't already obvious, is the King of Spain has no beard. Therefore, asking what colour his beard is doesn't make sense.

Originally when we developed our API around kings and beards, that's not something we gave much thought to, and in the instance where a `King` has no `Beard`, we returned `null`, more by accident than design. That's easy to do in a language where the entire SDK has been built around `null` as a signifier of an absence of a sensible answer for the best part of 20 years.

So now we acknowledge it's possible for a king to *not* have a beard, we modify our API so `getBeard()` returns an `Optional<Beard>` for the color instead of a `Beard`, and our code looks like this:

```java
public static String getKingBeardColor(Country country) {
    King king = country.getKing();
    Optional<Beard> beard = king.getBeard();
    Optional<String> color = beard.map(Beard::getColor);
    return color.orElse("n/a"); 
}
```

or, if you're OK being less explicit about types:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .getBeard()
                  .map(Beard::getColor)
                  .orElse("n/a"); 
}
```

We test this with the current King of Spain, and all looks sensible, so we deploy our change to production, and we go ever so slightly longer before we hit another `NullPointerException`.

At this point we have three thoughts, in roughly the following order:
 - Arsebiscuits!
 - Why did I ever think monarch-beard-colors-as-a-service was a viable startup to join?
 - Where exactly is this failing and with what inputs?

As frustrating as it is, this is a problem you *do* need to solve, if only because you've got too much tied up in equity to give up now. So you look at the logs and see that someone queried for the color of the beard of the King of *France*. What's the problem there? 

### The King of France's beard

This is the King of France:

![The current King of France](https://ethicsalarms.files.wordpress.com/2016/02/empty-podium.jpg?w=400)

There hasn't been a King of France since 1870. For that matter, there hasn't been a King of England since 1952. It's *entirely possible* for a country to not have a king.

Before we update our API, seeing as we've already had two production outages, we get a little paranoid and take a moment to think about whether it's possible for a `Beard` to not have a color. We decide that it isn't (grey and white are, after all, colors). We also decide that, seeing as beard colors are `String`s, a beard which is, say, brown and grey can be described simply enough with a single return value.

So we end up with code looking a bit more like this:

```java
public static String getKingBeardColor(Country country) {
    Optional<King> king = country.getKing();
    Optional<Beard> beard = king.map(King::getBeard);
    Optional<String> color = beard.flatMap(Beard::getColor);
    return color.orElse("n/a"); 
}
```

Which you may choose to inline to something like this:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .map(King::getBeard)
                  .flatMap(Beard::getColor)
                  .orElse("n/a"); 
}
```

And all is looking good in the world. Up to a point.

Up to the point, that is, when you get a new requirement in. It turns out that your customers aren't entirely satisfied with that `"n/a"` they get when there isn't a sensible answer to the question of "what's the color of the king of X's beard?"

On the face of it, that's reasonable. You're still curious exactly what your customer base is, let alone how you're going to monetise it, but that's beyond the scope of this blogpost.

So you start thinking about how to represent said failures. One approach suggests itself, but it's somewhat clunky:

```java
public static String getKingBeardColor(Country country) {
    Optional<King> king = country.getKing();
    if(!king.isPresent()) {
        return country.name() + " does not have a king";
    }
    Optional<Beard> beard = king.map(King::getBeard);
    if(!beard.isPresent()) {
        return king.get().name() + " does not have a beard";
    }
    Optional<String> color = beard.flatMap(Beard::getColor);
    return color.orElse("n/a"); 
}
```

Or maybe, seeing as we understand the importance of not calling `Optional::get`:

```java
public static String getKingBeardColor(Country country) {
    Optional<King> king = country.getKing();
    return king.map(KingBeards::getBeardColor)
               .orElseGet(() -> country.name() + " does not have a king");
} 

public static String getBeardColor(King king) {
    return king
        .getBeard()
        .map(Beard::color)
        .orElseGet(() -> king.name() + " does not have a beard");
}
```

Both ways work, but both are slightly hideous. You had a nice clean pipeline of composed operations and now you need to poke in the middle of them and check what's going on.

This is where you start riding up against the big limitation of `Optional`. Its purpose is to communicate the possibility of failure, and ensure it's handled. One thing that's super nice about it is that it's composable with other operations which return an `Optional`. But there's one facet of failure it doesn't consider.

When things fail, they fail for a reason. `Optional`s allow successes to propagate through operations, but all failures are reduced to a simple "sorry, no value for you" case.

Enter `Result`.

### Result!

A `Result` is such a tiny step from `Optional` it's almost embarassing.

An `Optional` is one of two things: either it's a success, containing a value, or it's a failure.

A `Result` is one of two things: either it's a success, containing a value, or it's a failure, *containing a value describing the failure*.

How often can things fail *and you care how*? That's a place where you should consider using a `Result`.

So let's compare how that code can look, using first `Optional`s and not caring about the error-case:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .map(King::getBeard)
                  .flatMap(Beard::getColor)
                  .orElse("n/a"); 
}
```

And secondly using `Result`s, and reporting details about the error:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .map(King::getBeard)
                  .flatMap(Beard::getColor)
                  .either(success -> success,
                          failure -> failure); 
}
```

The latter case assumes that `Country::getKing` and `King::getBeard` return a `Result<King, String>` and a `Result<Beard, String>` respectively, offering sensible descriptions when the operation fails.

### Optionals *are* Results

From one perspective, an `Optional` is just a special case of `Result`, where the failure type is chosen to convey no useful information.

There's one big pro on the side of `Optional` over `Result`: `Optional` is in the Java 8 API, whereas `Result` isn't. That means it's already there, other devs will be well-acquainted with its API, and other APIs will interface via `Optional`s.

On those points:
- It's really very simple to implement your own, or you could use [this one we open-sourced](https://github.com/unruly/control). 
- The API could look exactly like the `Optional` API, only with some enhancements around dealing with failure-cases. In the linked example it doesn't, because functions are better than methods, which I'll get onto later.
- It's trivial to convert between `Result` and `Optional` at module boundaries.

All the operations you're used to on an `Optional` - you can do those on a `Result`, only now those can be augmented by operations which deal with failure values too. This means you can continue to think in terms of pipelines of operations.

### How I built Result

Ultimately, a `Result<S, F>` is a generic type over two types: the type of a success, and the type of a failure. In terms of data structure, all you need is something which is *either* a success *or* a failure. It must be one or the other, and it can't be both. In Haskell, this would be a one-liner:

```haskell
data Result s f = Success s | Failure f
```

In Java, it's *just a tad* more complex:

```java
public abstract class Result<S, F> {
    private Result() {}

    public abstract <R> either(Function<S, R> onSuccess, Function<F, R> onFailure);

    public static final class Success<S, F> extends Result<S, F> {
        private final S value;
        public Success(S value) { this.value = value; }
        public <R> either(Function<S, R> onSuccess, Function<F, R> onFailure) {
            return new Success(onSuccess.apply(value));
        }
    }

    public static final class Failure<S, F> extends Result<S, F> {
        private final F value;
        public Success(F value) { this.value = value; }
        public <R> either(Function<S, R> onSuccess, Function<F, R> onFailure) {
            return new Failure(onFailure.apply(value));
        }
    }
}
```

This creates a type `Result` with two subtypes `Success` and `Failure`. It's impossible to create further subtypes, so any `Result` is either a `Success` or a `Failure`. The only way to access the contents is via a single method `Result::either`, which requires the caller specify how to handle each case.

Not only that, but it encourages a syntactic style that's reminiscent of pattern-matching in more functional languages, where we split down the possible cases and handle each separately. 

For example, in Haskell, you might write `map` as follows:

```haskell
map :: (s -> s') -> Result s f -> Result s' f
map f (Success x) = Success (f x)
map f (Failure x) = Failure x
```

The same function in Java:

```java
public static <S, S1, F> map(Result<S, F> result, Function<S, S1> mapper) {
    return result.either(
        s -> new Success<>(mapper.apply(s)),
        f -> new Failure<>(f)
    );
} 
```

### Methods vs Functions

That `map` function could, instead, be written as a method on `Result`: that would be in line with what `Optional` does.

The problem with methods, though, is that if you present an API where you can do three things with an object, those are the only three things your consumers are ever likely to do. If you present an API where you provide a higher-level abstraction and then implement three things *using it*, then not only will people use those three things, they're more likely to build their own ad-hoc extensions to it.

That's why I implemented `map`, `flatMap` and so on as static methods (ie, functions) in terms of `Result::either`. Firstly because I *can*: any possible interaction with a `Result` can be implemented through `Result::either` - and secondly because *you can too*. The library provides many useful patterns but I'm not going to pretend I've considered every use-case, so it's easy to augment it as per your requirements *and retain the same calling conventions*. 

That's not to say that this approach to API design is pure upside: for starters, your IDE is less useful because you don't have auto-complete on methods. Secondly, composing operations on a `Result` is considerably less elegant.

Whereas a method-based API would allow us to do the following:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .map(King::getBeard)
                  .flatMap(Beard::getColor)
                  .either(success -> success,
                          failure -> failure); 
}
```

With just functions, we could write:

```java
public static String getKingBeardColor(Country country) {
    return flatMap(
               map(country.getKing(), King::getBeard), 
               Beard::getColor
           ).either(
               success -> success,
               failure -> failure
           ); 
}
```

At this point, our reasoning is getting considerably more tangled. Order of operations isn't so clear any more, and that's when we paid particular attention to formatting. That the `flatMap` is being applied to the output of mapping getKing() to getBeard(), even though the `flatMap` is written before the `map` despite the `map` having to be called first...

All of this is decipherable with practise. That's not the point. The point is we've gone from a typical calling convention where operations are listed in order to one where they're not. Maybe the other benefits of such an API design mean that's a worthwhile tradeoff, and maybe they don't.

Fortunately, that's not a division we need to choose a side on. The functional approach described above is far from ideal, because it's not using the API in the right way. It's approaching it from a noun-composition perspective, whereas what it *ought* to be doing is approaching it from a verb-composition perspective.

What do I mean by that? All will become clear when I start talking about the use-case that motivated me to write this library in the first case: validation.

But that's something that deserves a post all of its own.