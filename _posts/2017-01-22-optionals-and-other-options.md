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

 <!--more-->

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
    Optional<Beard> beard = king.flatMap(King::getBeard);
    Optional<String> color = beard.map(Beard::getColor);
    return color.orElse("n/a"); 
}
```

Which you may choose to inline to something like this:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .flatMap(King::getBeard)
                  .map(Beard::getColor)
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
    Optional<Beard> beard = king.flatMap(King::getBeard);
    if(!beard.isPresent()) {
        return king.get().name() + " does not have a beard";
    }
    Optional<String> color = beard.map(Beard::getColor);
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

So let's compare how that code can look, using first `Optional`, not caring about the error-case:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .flatMap(King::getBeard)
                  .map(Beard::getColor)
                  .orElse("n/a"); 
}
```

And secondly using (a hypothetical implementation of) `Result`, reporting details about the error:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .flatMap(King::getBeard)
                  .map(Beard::getColor)
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
- The API could look exactly like the `Optional` API, only with some enhancements around dealing with failure-cases. In the linked example it doesn't, because functions are better than methods.
- If you really need `Optional`s, it's trivial to convert between `Result` and `Optional` at module boundaries.

All the operations you're used to on an `Optional` - you can do those on a `Result`, only now those can be augmented by operations which deal with failure values too. Whereas an `Optional` pipeline will continue operations until it hits an `empty` value (yielding `empty` at the end), a `Result` pipeline can continue operations until it hits a `failure` value (yielding *that* failure at the end). This means you can continue to think in terms of pipelines of operations.

### How I built Result

Ultimately, a `Result<S, F>` is a generic type over two types: the type of a success, and the type of a failure. In terms of data structure, all you need is something which is *either* a success *or* a failure. It must be one or the other, and it can't be both. In Haskell, this would be a one-liner:

```haskell
data Result s f = Success s | Failure f
```

In Java, it's *just a tad* more verbose:

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

Unfortunately, this is basically the minimal case of an algebraic data type in Java.

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
    return result.either(s -> new Success<>(mapper.apply(s)), Failure::new);
} 
```

And, for good measure, here's `flatMap`:

```java
public static <S, S1, F> flatMap(Result<S, F> result, Function<S, Result<S1, F>> mapper) {
    return result.either(s -> mapper.apply(s), Failure::new);
} 
```

### Methods vs Functions

That `map` function could, instead, be written as a method on `Result`: that would be in line with what `Optional` does, and what Java developers would expect. 

The problem with methods, though, is one of extensibility. In object-oriented programming, it's easy to add new *types* which support a given set of operations: it's much harder to add an operation to a given type. For example, let's say we have some code which takes an `Optional` and fires an event based on its content, if it's present:

```java
public static logEvents(Optional<String> maybeEvent) {
    maybeEvent.ifPresent(LOG::info);
}
```

But now we want to log an *error* if we don't get an event at all, well. There's an `ifPresent()` method on `Optional`, but no `ifAbsent()`. This means we have various options, none of which are particularly inspiring:

```java
// this approach is noisy, will lead to us repeating ourselves,
// and inverting conditions is difficult to read and easy to bug out
public static justInlineIt(Optional<String> maybeEvent) {
    maybeEvent.ifPresent(LOG::info);
    if(!maybeEvent.isPresent()) {
        LOG.error("No event present");
    }
}

// this abstracts out the ifAbsent case, but it's inconsistent with the
// ifPresent call and it's not obvious the two lines are complementary
public static utilityFunction(Optional<String> maybeEvent) {
    maybeEvent.ifPresent(LOG::info);
    ifAbsent(maybeEvent, () -> LOG.error("No event present"));
}


// this gives us a consistent set of operations on the event, but
// it's inconsistent with other usages of the Optional API
public static utilityFunction(Optional<String> maybeEvent) {
    ifPresent(maybeEvent, LOG::info);
    ifAbsent(maybeEvent, () -> LOG.error("No event present"));
}

// and our helper functions

public static <T> ifAbsent(Optional<T> maybe, Runnable task) {
    if(!maybe.isPresent) {
        task.run();
    }
}

public static <T> ifPresent(Optional<T> maybe, Consumer<T> consumer) {
    maybe.ifPresent(consumer);
}
```

That's why I implemented `map`, `flatMap` and so on as static methods (ie, functions) in terms of `Result::either`. Firstly because I can: *any possible interaction* with a `Result` can be implemented through `Result::either` - and secondly because *you can too*. The library provides many useful patterns but I'm not going to pretend I've considered every use-case, so it's easy to augment it as per your requirements *and retain consistent calling conventions*. 

So, where a method-based API would allow us to do the following:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .flatMap(King::getBeard)
                  .map(Beard::getColor)
                  .either(success -> success,
                          failure -> failure); 
}
```

With just functions, we could write:

```java
public static String getKingBeardColor(Country country) {
    return map(flatMap(country.getKing(), King::getBeard), 
               Beard::getColor
           ).either(
               success -> success,
               failure -> failure
           ); 
}
```

But this is ugly. Order of operations isn't so clear any more, and that's when we paid particular attention to formatting. That the `flatMap` is being applied to the output of mapping getKing() to getBeard(), even though the `flatMap` is written before the `map` despite the `map` having to be called first...

It doesn't have to be this way, though.

### The Applicable Pattern

There's no need for a tradeoff between versatility and readability here. We can just add another method to `Result`.

```java
public abstract class Result<S, F> {
    private Result() {}

    public abstract <R> either(Function<S, R> onSuccess, Function<F, R> onFailure);

    public <T> then(ResultMapper<S, F, T> mapper) {
        return mapper.onResult(this);
    }

    // subtypes elided...
}

@FunctionalInterface
public interface ResultMapper<S, F, T> {
    T onResult(Result<S, F> result);
}
```

I call this the Applicable Pattern. All the method `then` does is invert the calling convention: instead of passing an object to a function, you pass a function to an object. That does mean we need to express our functions in curried form instead:

```java
public static <S, S1, F> ResultMapper<S, F, Result<S1, F>> map(Function<S, S1> mapper) {
    return r -> r.either(s -> new Success<>(mapper.apply(s)), Failure::new);
} 

public static <S, S1, F> ResultMapper<S, F, Result<S1, F>> flatMap(Function<S, Result<S1, F>> mapper) {
    return r -> r.either(s -> mapper.apply(s), Failure::new);
} 
```

This allows us to take all those functions, and compose them sequentially instead:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .then(flatMap(King::getBeard))
                  .then(map(Beard::getColor)) 
                  .either(success -> success, 
                          failure -> failure); 
}
```

This is only marginally noisier than implementing it with regular methods:

```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .flatMap(King::getBeard)
                  .map(Beard::getColor)
                  .either(success -> success,
                          failure -> failure); 
}
```

There's a little boilerplate in having to wrap our function calls in calls to `then`. That's a minor cost. A larger cost is the impact on discoverability: now our auto-completion can't tell us what we can do with a Result, beyond passing it two `Function`s or a `ResultMapper`. That's the point, though: we don't want to define a restricted set of operations.

For example, we often end up with the `Success` and `Failure` types being the same type, and we want to return whatever the current value is, be it success or failure. We've been calling `either` in our examples, but we could just as easily make that a function:

 ```java
public static String getKingBeardColor(Country country) {
    return country.getKing()
                  .then(flatMap(King::getBeard))
                  .then(map(Beard::getColor)) 
                  .then(collapse()); 
}

static Function<Result<T, T>, T> collapse() {
    return r -> either(s -> s, f -> f);
}
```

We might want to map `Failure` values to new values/types, leaving `Success`es unchanged. We might want to convert a `Result<S, F>` to an `Optional<S>`, throwing away the failure value, to interact with some other API. We might want to invert a `Result`, flipping it so what was a `Success` is now a `Failure` and vice versa. And we might want to do many such operations, in sequence in a pipeline. 

These are trivial functions to write, and now they can be integrated to extend the toolkit we have at our disposal - because we can bring tools into the toolkit from different packages.

### Are we nearly there yet?

If you're dealing with operations which can fail, and you care how they fail, then a `Result` datatype is a good model for that. Operations which can fail are kind of our stock in trade.

This particular implementation of `Result` is designed to be easily composable and extensible. Common operations are provided, and more niche functionality is easily integrated after the fact.

There are many ways to compose and apply some simple operations on `Result`s to build clean approaches to common problems, such as validation, and useful techniques not available in vanilla Java, like flow typing. I'll talk about some of the key examples in the next post.