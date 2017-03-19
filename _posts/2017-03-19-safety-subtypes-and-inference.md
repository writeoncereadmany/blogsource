---
layout: post
title: Safety, subtypes and inference
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

Using `Result` to model potentially-failing-operations is safe in two ways. Firstly, it requires you to be explicit about how you're handling failure cases. Secondly, it requires you to maintain a consistent model of what those successes and failures are, in order to *allow* sensible handling of them.

<!--more-->

For example, this code is perfectly fine:

```java
public Result<Integer, String> isHalfNPrime(int n) {
    return divideExactlyByTwo(n)
        .then(flatMap(this::isPrime));
}

private Result<Integer, String> divideExactlyByTwo(int number) {
    return number % 2 == 0
        ? Result.success(number / 2)
        : Result.failure(number + " is odd: cannot divide exactly by two");
}

private Result<Integer, String> isPrime(int number) {
    return IntStream.range(2, (int) Math.sqrt(number))
        .anyMatch(possibleDivisor -> number % possibleDivisor == 0)
            ? Result.success(number)
            : Result.failure(number + " is not prime");
}
```

But this code isn't:
```java
public Object isHalfNPrime() {
    Result<Integer, Object> foo = "!!blue!!"divideExactlyByTwo(4)"!!end!!"
        .then(flatMap("!!pink!!"this::listFactors"!!end!!"));
}

private Result<Integer, String> divideExactlyByTwo(int number) {
    return number % 2 == 0
        ? Result.success(number / 2)
        : Result.failure(number + " is odd: cannot divide exactly by two");
}

private Result<Integer, List<String>> listFactors(int number) {
    List<String> primeFactors = IntStream
        .range(2, (int) Math.sqrt(number))
        .filter(possibleDivisor -> number % possibleDivisor == 0)
        .mapToObj(divisor -> number + " is divisible by " + divisor)
        .collect(Collectors.toList());

    return primeFactors.isEmpty()
        ? Result.success(number)
        : Result.failure(primeFactors);
}
```

In the latter case, the blue function returns a `Result<Integer, String>`, then we `flatMap` over the pink function, which returns a `Result<Integer, List<String>>`. That means we have an inconsistent idea of what type a failure is, and therefore can't do anything reasonable with it. 

Let's talk briefly about `flatMap` and why it can give us typing problems.

### FlatMap on Results: What Does It Mean?

When we have a functional pipeline, that normally means we have an input type and an output type. We can put functions in the pipeline which transform types, and as long as each function's input type matches its predecessor's output type, we're fine. Nonetheless, at any point in the pipeline, we know exactly what the type is.

When we're dealing with `Result`s, though, we have two parallel pipelines: one for successes, and one for failures. Some functions can cross from one pipeline to another. `flatMap` is one of those. 

What `flatMap` does is take a function which takes a success type and returns a `Result`, and applies it to successes in the pipeline. If they're successful, it outputs a new success. This is guaranteed to be fine: any input successes can have any arbitrary output success types. 

The same is not true for failures. At that point in the pipeline, we can take failures from further upstream, *or* we can generate new failures from the output of our function that was an input to `flatMap`. If the types of the pre-existing failure pipeline and the output of the `flatMap`'d function don't match, then we've lost type coherence.

`flatMap` is not unique in this sense, it's just the most common pipeline-crossing operation.

Fortunately, the compiler is our friend, and tells us when we get such type errors: even when we're not picky about what we return, `isHalfNPrime` does not compile. There are various ways of fixing this: we could say we want our failure case to be a list of strings:

```java
public Result<Integer, List<String>> isHalfNPrime() {
    Result<Integer, Object> foo = divideExactlyByTwo(4)
        .then(mapFailures(Collections::singletonList))
        .then(flatMap(this::listFactors));
}
```

Or we could say we want our failure case to be a single string:

```java
public Result<Integer, String> isHalfNPrime() {
    Result<Integer, Object> foo = divideExactlyByTwo(4)
        .then(flatMap(this::listFactors));
}

private Result<Integer, String> listFactors(int number) {
    List<String> primeFactors = IntStream
        .range(2, (int) Math.sqrt(number))
        .filter(possibleDivisor -> number % possibleDivisor == 0)
        .mapToObj(divisor -> number + " is divisible by " + divisor)
        .collect(Collectors.toList());

    return primeFactors.isEmpty()
        ? Result.success(number)
        : Result.failure(String.join(", ", primeFactors);
}
```

But in order to make this compile, we need to be conscious of what type we use to represent successes and failures at each point in the computation, and ensure they line up properly. This is entirely desirable, because otherwise we can't deal with the failure cases sensibly. It's also desirable that we catch this error at the point our types diverge: the earlier and more specifically that we can locate our errors, the better.

That's all well and good in straightforward examples like this, but it's not always quite so black and white. One case we ran into recently involved validation.

### Validation

Validation is a particularly common class of potentially-failing-operation, which has one defining property and a number of emergent properties. The defining property is: 

*Validating an object does not modify it.*

I don't just mean it doesn't mutate the object: I mean that a successful validation returns the same input object, as opposed to building a new object and returning that.

This then implies it is possible to run multiple validations on the same object, possibly in parallel, and collapse them down into a single validation. Either all succeed, in which case we return a success of our input object, or they don't.

If they don't all succeed, what do we want our failure type to be? One answer might be "the list of errors". That's certainly better than arbitrarily choosing one of the errors, such as the first, but we frequently want more than that. 

When we're validating user input, we want to be able to return feedback to our user that helps them fix whatever made their input fail validation. In that case, sometimes nice, specific error messages are lacking in context. In addition to the errors, it's often useful to include the input that made it fail. 

You may be thinking "In that case, just include the context in the error messages". That's fine if you have one error message: less so if you have twenty, all repeating the same (potentially large) input object.

In addition, if you return a tuple of the input object and the errors, you can feed the output of one validation into another to compose them into a single, larger validator. If all you had was the list of errors, you no longer have an input object to apply validation to.

So that's what a validation is, in the context of this library: a function which takes an input object, collates errors on it, and returns either the input object or a `FailedValidation<T, E>`, which contains the input object (of type `T`) and all the errors (each of type `E`). That gives us everything we are likely to need when validating.

### What Makes Sense In Isolation, Doesn't Always In Context.

The only problem here is that we don't always need all of that. 

Oftentimes we want to run validations as part of a functional pipeline of steps: we might do some simple validations on our initial input object, then do some transformations, then validate the result of that, then persist it (persistence is *almost always* a potentially-failing-operation). For example, we may want to do something like this:

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m, 
        fizzbuzz
        .then(map(x -> Integer.toString(x)))
        .then(flatMap(under100))
        .then(map(s -> "Great success! " + s))
        .then(mapFailure(f -> 
            "Big fails :( " + String.join(", ", f.errors)))
        .andFinally(collapse()));
}
```

The only trouble here is: `FailedValidation<T, E>` is not a useful failure type in this sort of pipeline. If we validate, transform to another type, then validate again, we can't have a consistent failure type, because the `T` parameter is different before and after the transformation. Here, we'd be happy with just the list of errors, which is one of the two ubiquitous failure types (the other being `Exception`).

There are various approaches here. One is to take the output of the validation and map failures to just the list of errors:

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m,
        (fizzbuzz
            .then(treatFailuresAsList())
        .then(map(x -> Integer.toString(x)))
        .then(flatMap(under100
            .then(treatFailuresAsList()))))
        .then(map(s -> "Great success! " + s))
        .then(mapFailure(f -> 
            "Big fails :( " + String.join(", ", f)))
        .andFinally(collapse()));
}
```

This works, but it's not super approachable or discoverable. 

We have a new level of nesting that's appeared: we're modifying the functions *within* a mapping, rather than adding to the top-level pipeline - but that's needed because we need to unify the types before returning to the level of the pipeline. This adds another layer of complexity, which is the last thing we need.

It's also bad for discoverability because the first time you come across this case, if you're good, you'll stare at the type errors for a bit, do some extraction of variables, and eventually work out why it's not compiling. Working out how to solve it, though, requires enough experience to know that this is the trick you need in this situation. This is not friendly for newcomers.

So we started reconsidering whether or not we'd just be better off with a list of errors in the first place. In doing so, we came up with a nice idea.

### A Nice Idea

What if our `FailedValidation<T, E>` *was* a `List<E>`? It contains a list, so surely we can present it as one? It's even pretty simple to do using a cool pattern that takes advantage of default methods:

```java
public interface ForwardingList<T> extends List<T> {

    List<T> delegate();

    default int size() { return delegate().size(); }

    default boolean isEmpty() { return delegate().isEmpty(); }

    ... etc for the other 28(!) methods on the List interface ...
}
```

Just implement `ForwardingList` on your type, and implement the `delegate()` method which presents the object as a list, and you're done. 

Even implementing `ForwardingList` (or any other forwarding interface) isn't hard. It's a lot of code, sure, but you don't need to write it manually: any good IDE and a little bit of regex-fu will get you there. There are lines of code in there which have never been viewed by human eyes.

So, now our `FailedValidation` is a `List`, we're sorted, right?

Well, no. Even though a `FailedValidation` is a `List`, that doesn't mean it is a `List`. 

### A Brief Note On Subtyping, Variance and Generics

Now, a `FailedValidation` is a *subtype* of `List`. That means we can assign a `FailedValidation` variable to a `List` variable. We can't assign a `List` variable to a `FailedValidation`, though: all `FailedValidation`s are `List`s but not vice-versa.

But we're not dealing with `FailedValidation`s in this case: we're dealing with `Function`s and `Result`s over `FailedValidation`s, and in that case we need to understand the difference between covariance and contravariance. Let's just look at functions, to start off with.

In principle, a sufficiently smart compiler would know that a `Function<String, FailedValidation>` is a subtype of `Function<String, List>`. Anywhere you need a function which returns a `List`, you can use a function which returns a `FailedValidation`, because the return values you get *are* `List`s. This is *co*variance: the subtyping rules of the type parameter are the same as they would be for a regular variable.

Similarly, a sufficiently smart compiler would know that a `Function<List, String>` is a subtype of `Function<FailedValidation, String>`. Anywhere you will pass a `FailedValidation` to a function will work if the function takes any `List`, as the `FailedValidation` *is* a list. The inverse is not true: a function which takes only a `FailedValidation` and, for example, looks at its input parameter, will *not* work if passed a `List`, so you can't assign a `Function<FailedValidation, String>` to a `Function<List, String>`. This is *contra*variance: the subtyping rules of the type parameter in that position are inverted from the subtyping rules or a regular variable.

The trouble with Java is: it's not sufficiently smart. We have to be specific about how we want variance to work. Just to make life even harder, we have to do it with ugly, shoe-horned syntax in order to avoid introducing new keywords in Java 5. To put the frustration cherry on the top of the iceberg, we can't even make principled statements about types like `Function<I, O>` to make the input type contravariant and the return type covariant for us (declaration-site variance): we have to handle variance modifiers every time we *use* the type (use-site variance)...

Anyway.

### Now Back To The Good Part

What we'd *like*, in an ideal world, is to have a situation where if we have a `Result<T, List<E>>`, then we can `flatMap` it over something which provides a `Result<T, FailedValidation<?, E>>` and we end up with a `Result<T, List<E>>`. We know this is safe, because all we can do with a failure type is read it, and a `FailedValidation` is readable as if it were a `List`. 

Well, good news everybody! That's entirely possible! Let's start by looking at the original implementation of `flatMap`:

```java
public static <S, S1, F> Function<Result<S, F>, Result<S1, F> flatMap(Function<S, Result<S1, F>> f) {
    return r -> r.either(f, Result::failure);
}
```

Super simple: it takes in a function which takes a success and outputs a success or failure, and then returns a function which takes a `Result` and, if it's a success, returns the output of running the input function on the success value, otherwise it returns the original failure. 

Let's see how we can make it do what we want with generalising to lists:

```java
public static <IS, OS, OF, IF extends OF, FF extends OF> 
    Function<Result<IS, IF>, Result<OS, OF>> flatMap(Function<IS, Result<OS, FF>> f) 
{
    return r -> r.either(
        success -> f.apply(success).then(mapFailure(Results::upcast)),
        fail -> Result.<S1, IF, IF>failure(fail).then(mapFailure(Results::upcast)));
}

private static <R, T extends R> R upcast(T fv) {
    return fv;
}
```

Oookay, that's a little harder to grok. We have input and output success and failure types (IS, OS, IF, OF), and an additional failure type FF which comes from the mapping function. Furthermore, we have relationships between types: the output failure type is a supertype of both the input failure type and the mapping function's failure type.

We also have a function `upcast` which appears to do exactly nothing, other than its return type is an arbitrary(?) supertype of the input value, and we're mapping failures over that to... get the same value back, only this time the containing result has upcast it to an arbitrary(?) supertype?

Yeah, that's what happens. Fortunately the compiler does some appropriate magic and finds the most appropriate (read: specific) type for the failure type, and converges on that. And with that implementation, our originating example compiles (and, of course, does exactly what we want):

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m,
        (fizzbuzz
        .then(map(x -> Integer.toString(x)))
        .then(flatMap(under100)))
        .then(map(s -> "Great success! " + s))
        .then(mapFailure(f -> "Big fails :( " + String.join(", ", f)))
        .andFinally(collapse()));
}
```

So, now we can handle this particularly awkward case, by finding situations where the types might not align *exactly*, but we can go to the most specific common supertype and use that instead. 

Isn't that nice?

### The Danger of Nice Things

Our problem here is that we've been looking at two types which are very similar, which are very closely related. We had two failure types which were more specific than we wanted, and by using some compiler magic, we converged on the type that we wanted.

It doesn't always shake out like that. This change, as useful as it was in this particular narrow use case, breaks something important.

The problem with finding the most specific common supertype, as a default behaviour, is that *any two types have a common supertype*. A lot of the time it's going to be `Object`.

One thing this change does is it makes this compile:

```java
public Result<Integer, Object> isHalfNPrime() {
    Result<Integer, Object> foo = divideExactlyByTwo(4)
        .then(flatMap(this::listFactors));
}

private Result<Integer, String> divideExactlyByTwo(int number) {
    return number % 2 == 0
        ? Result.success(number / 2)
        : Result.failure(number + " is odd: cannot divide exactly by two");
}

private Result<Integer, List<String>> listFactors(int number) {
    List<String> primeFactors = IntStream
        .range(2, (int) Math.sqrt(number))
        .filter(possibleDivisor -> number % possibleDivisor == 0)
        .mapToObj(divisor -> number + " is divisible by " + divisor)
        .collect(Collectors.toList());

    return primeFactors.isEmpty()
        ? Result.success(number)
        : Result.failure(primeFactors);
}
```

And we started off by saying how having this fail to compile, due to incoherent failure types, was a desirable thing.

So let's see if we can find a better way.

### Can We Have Our Cake And Eat It?

What we really want to avoid here is accidentally over-generalising our failure type, whilst at the same time allowing safe generalisations. Is there any sensible way of distinguishing between them in a principled way? Well, let's look at the possible cases in turn:

1. Incoming Failure Type Exactly Matches Existing Failure Type
 * We're happy! This is how we wished the world always works.
2. Incoming Failure Type Is Subtype Of Existing Failure Type
 * In this case, we're not generalising the failure type: we're just allowing our overly-specific new failure provider to be consistent with the existing failure type. It seems reasonable to allow this to be upcast.
3. Incoming Failure Type Is Supertype Of Existing Failure Type
 * This is probably a result of using an overly-specific failure type earlier in the chain, so it's probably fair to generalise the type to the incoming failure type. It seems reasonable to allow this to be upcast.
4. Incoming Failure Type Is Neither Subtype Nor Supertype Of Existing Failure Type
 * There are some cases where this is reasonable to upcast, but *all the cases where it isn't* inhabit this zone. This is what we want to specifically disallow.

Okay. So, it'd be nice if we could allow our magic to work in cases 1, 2 and 3, but not 4. Our original, simple version of `flatMap` does 1 already. Now we know the tricks, it's easy to write it so it does 2:

```java
public static <S, S1, F, FF extends F> Function<Result<S, F>, Result<S1, F> 
    flatMap(Function<S, Result<S1, FF>> f) 
{
    return r -> r.either(
        success -> f.apply(success).then(mapFailure(Results::upcast)),
        Result::failure
    );
}

private static <R, T extends R> R upcast(T fv) {
    return fv;
}
```

And it's easy to write it so it does 3:

```java
public static <S, S1, F, IF extends F> Function<Result<S, IF>, Result<S1, F>> 
    flatMap(Function<S, Result<S1, F>> f) 
{
    return r -> r.either(
        f,
        fail -> Result.<S1, IF, IF>failure(fail).then(mapFailure(Results::upcast)));
}


private static <R, T extends R> R upcast(T fv) {
    return fv;
}
```

But it's not possible, as far as I can see, to write it so it does 2 and 3 at the same time, but *doesn't* do 4. Well, I can't see a way: it would be the height of hubris to say it's not possible just because I can't see a way of doing it. That's never stopped me before, though.

We *could* have two methods, one which generalises towards the predecessor failure and one which generalises towards the incoming failure, but that feels like it requires too much prior knowledge to make use of it properly. We could have it do neither, and rely on the user to make types conform, but that feels like throwing the baby out with the bathwater.

So let's assume we're using one or the other. How do we deal with the unhandled type mismatch in each case?

### We Can Do This The Easy Way, Or The Hard Way. JK Lol, This Is Java

We already have one way of transforming types: we map the failures. We had an example of this when we just had simple `FailedValidation` objects, and we decided we didn't like it because it introduced a level of nesting. Well, that's not necessarily true: we need to nest that failure transformation if our new failure type doesn't match the existing failure type, but if we want to align our existing failure type with a more general new failure type, we can do that at the basic pipeline level:

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m, 
        fizzbuzz
        "!!pink!!".then(mapFailures(treatFailuresAsList()))"!!end!!"
        .then(map(x -> Integer.toString(x)))
        .then(flatMap(under100))
        .then(map(s -> "Great success! " + s))
        .then(mapFailure(f -> 
            "Big fails :( " + String.join(", ", f.errors)))
        .andFinally(collapse()));
}
```

As it happens, the pink function here is actually doing a transformation - taking the list out of the `FailedValidation` - but we could just as easily make it a type coercion:

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m,
        (fizzbuzz
            .then(map(x -> Integer.toString(x)))
            "!!pink!!".then(WithTypes.<List<String>>forFailures().convert())"!!end!!"
            .then(flatMap(under100)))
            .then(map(s -> "Great success! " + s))
            .then(mapFailure(f -> "Big fails :( " + String.join(", ", f)))
            .andFinally(collapse()));
}
```

Well, I say just as easily, but it requires a little bit of behind-the-scenesery:

```java
public interface Types {
    static <NF> FailureConverter<NF> forFailures() {
        return new FailureConverter<NF>() {
            @Override
            public <S, T extends NF> Attempt<S, S, T, NF> convert() {
                return result -> result.then(mapFailure(Types::upcast));
            }
        };
    }

    interface FailureConverter<NF> {
        <S, F extends NF> Attempt<S, S, F, NF> convert();
    }

    static <R, T extends R> R upcast(T fv) {
        return fv;
    }
}
```

There are a couple of things that are a touch ugly here. It would be lovely if we could instead phrase our coercion like this:

```java
public String isThisAnInterview(int m) {
    Validator<Integer, String> fizzbuzz = Validators.compose(
        rejectIf(n -> n % 3 == 0, "fizz"),
        rejectIf(n -> n % 5 == 0, "buzz"));

    Validator<String, String> under100 = rejectIf(s -> s.length() > 2, s -> s + " is too damn high");

    return with(m,
        (fizzbuzz
            .then(map(x -> Integer.toString(x)))
            "!!pink!!".then(WithTypes.<List<String>>forFailures())"!!end!!"
            .then(flatMap(under100)))
            .then(map(s -> "Great success! " + s))
            .then(mapFailure(f -> "Big fails :( " + String.join(", ", f)))
            .andFinally(collapse()));
}
```

And thus skip the call to `convert()`, but I can't see a way of doing that, because `then()` expects an `Attempt` which has many types, and we want to only specify the type we care about: the target failure type. Doing our magic in the `convert` mechanism allows the other types to be inferred.

We could do it by making it an inferred generic call, where it does its magic on a parameter, such as a class - but while a class is fine when we have a non-generic failure type, we can't represent a generic `List<T>` via a class parameter. That's why it's important we have a syntax which allows explicitly stating arbitrarily nested generics as the target failure type.

Given how warty Java can be, if that's the most elegant I can make it, I'm not too upset. I think this is a pretty happy medium, on the whole.

### Summing Up

Sometimes we have a pipeline of `Result`s where the success or failure types aren't the same, and we need to highlight that early because it's evidence we've done something very wrong.

Sometimes we have a pipeline of `Result`s where the success or failure types aren't exactly the same, but it's reasonable to upcast one of them to the type of the other. It's not possible to systematically do this in a bilateral way, but it's better to do it for newly-incoming failures than existing failures for three reasons:

1. It's easier to compose operations at the top level - the only level which should exist - this way.
2. Upcasting incoming failures only widens types on one stage of failures, as opposed to arbitrarily many stages of failures that built the existing errors.
3. Failure types are clearer, as once a failure type is established at one point in the pipeline, the only way it can be changed is by explicit type-changing calls (be they coercions or mappings).

If I was working in Haskell, I wouldn't even need to think about this stuff. Subtypes are hard. :(