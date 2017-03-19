---
layout: post
title: On validation
author: Tom Johnson
published: false
excerpt_separator: <!--more-->
---

Let's say you're responsible for the head of the queue for a rollercoaster. You control the flow of people from the queue to the carriages, but before you allow them to pass to the ride itself, you validate them.

You might implement that with something like this:

```java
public static boolean canRide(Person person) {
    return person.getHeightInCm() > 120; 
}
```

Only thing is, this ride *also* has a height limit, as well as a minimum:

```java
public static boolean canRide(Person person) {
    return person.getHeightInCm() > 120 
        && person.getHeightInCm() < 210;
}
```

Plus, there's a list of medical conditions which it's unsafe to ride with:

```java
public static boolean canRide(Person person) {
    return person.getHeightInCm() > 120 
        && person.getHeightInCm() < 210
        && !person.getMedicalConditions()
                  .stream()
                  .anyMatch(DangerousConditions::contains);
}
```

And people get quite rightly annoyed when they're told they can't ride, but not *why not*:

```java
public static Optional<String> whyYouCantRide(Person person) {
    if(person.getHeightInCm() < 120) {
        return Optional.of("You must be this tall to ride");
    } else if(person.getHeightInCm() > 210) {
        return Optional.of("You must be under this height to ride");
    } else if (person.getMedicalConditions()
                  .stream()
                  .anyMatch(DangerousConditions::contains)) {
        return Optional.of("It is dangerous to ride when you suffer a condition");  
    } else {
        return Optional.empty()
    }
}
```

And some issues are addressable, so they want to know *all* the reasons why they failed validation:

```java
public static List<String> reasonsYouCantRide(Person person) {
    List<String> reasons = new ArrayList<>();
    if(person.getHeightInCm() < 120) {
        reasons.add("You must be this tall to ride");
    }
    if(person.getHeightInCm() > 210) {
        reasons.add("You must be under this height to ride");
    }
    if (person.getMedicalConditions()
                  .stream()
                  .anyMatch(DangerousConditions::contains)) {
        reasons.add("It is dangerous to ride when you suffer a condition");  
    }
    return reasons;
}
```

We don't even have anything very complicated here, and already it's getting verbose, stateful, difficult to read, and relies on the consumer to understand that an empty list is a passed validation and a non-empty list is a failed one.

Using a `Validation`, however, it could look like this:

```java
Validator<Person, String> canRide = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    onEach(Person::getMedicalConditions,
           rejectIf(DangerousConditions::contains, 
                    "It is dangerous to ride when you suffer a condition"))
);
```

I think that's a ton clearer and easier to maintain, and I'll go into detail as to why in a bit. 

Firstly, let's look at what it actually does:

`canRide` here is a function, which takes a `Person` and outputs a `Result`, so that's the equivalent of the old-school method. A `Result` of what, though? At this point, it's worth asking what a validation *is*, and what we want to get from it.

If a validation passes, we expect a `Success`, and we expect it to contain the value being validated.

If a validation fails, we expect a `Failure`, and we expect it to contain how the validation failed. We can be generic about what shapes these reasons can be, but we know two things about them:

- There can be more than one reason why an item failed a validation
- There must be *at least one* reason why an item failed a validation, otherwise it would be a success.

Furthermore, in the case when we get a `Failure`, we just don't want to know the reasons it failed: we'll often want to know the item it failed on, for appropriate error reporting.

So, when validating a `T`, with an error type of `E`, we can expect the output to be a `Result<T, FailedValidation<T, E>>`, where `FailedValidation<T, E>` contains a `T` of the value that failed validation and a non-empty list of `E` errors.

Because this is just a regular `Result`, we can then handle all the success-routing approaches we'd use in a regular pipeline of operations after validation's done.

So, I really like that syntax. Here are a few key reasons why:

### Declarativity

We're stating what we want to validate: what the rules are, and what we report when they're broken. We don't specify anything about *how* those rules are turned into the end result. This means when we look at the code, all we see is our validation rules, not the mechanics of making it happen.

I'll talk about those mechanics shortly.

### Separation of concerns

```java
Validator<Person, String> canRide = compose(
    "!!green!!"rejectIf"!!end!!"("!!pink!!"person -> person.getHeight() < 120"!!end!!","!!blue!!" "You must be 1m20 tall to ride" "!!end!!"),
    "!!green!!"rejectIf"!!end!!"("!!pink!!"person -> person.getHeight() > 210"!!end!!", "!!blue!!" "You must be under 2m10 to ride" "!!end!!"),
    onEach(Person::getMedicalConditions,
           "!!green!!"rejectIf"!!end!!"("!!pink!!"DangerousConditions::contains"!!end!!",
                    "!!blue!!" "It is dangerous to ride when you suffer a condition" "!!end!!"))
);
```

Green code is the type of query we're running. Pink is the condition. Blue is the consequence if the condition fails. These concerns are all nicely expressed at the top level, in a manner where it's easy to see what's linked to what, and each part stands alone.

That might sound like a gimme, but it's easy to write validation code where the test and the message get incredibly intertwined. There are use cases where this does get more complex, and I'll touch on those later. For now, though, it's a big win that the basic case handles this nicely.

### Domain language

```java
Validator<Person, String> canRide = compose(
    "!!pink!!"rejectIf"!!end!!"(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    "!!pink!!"rejectIf"!!end!!"(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    "!!pink!!"onEach"!!end!!"(Person::getMedicalConditions,
           "!!pink!!"rejectIf"!!end!!"(DangerousConditions::contains, 
                    "It is dangerous to ride when you suffer a condition"))
);
```

Instead of using abstract terms like `filter`, `map` and `flatMap`, we use language which is relevant to the job at hand. We might be using standard functional data structures under the hood, but that doesn't mean we have to just propagate that API.

There's often a tendency in functional APIs to have methods which take `Predicate`s, and it's not always entirely clear what the `Predicate` returning `true` *means*. Does a `true` mean we filter *out* a value from a stream, or it *passes through* the filter? With this choice of language, the consequences of truth are nice and clear: we reject.

### Composability

We can see that we're composing validators: the first call is to `compose`. What's not immediately clear is that we can do so on a much more granular scale:

```java
Validator<Person, String> checkHeight = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride")
);

Validator<MedicalCondition, String> checkMedicalCondition = rejectIf(
    DangerousConditions::contains, 
    "It is dangerous to ride when you suffer a condition")
)

Validator<Person, String> canRide = compose(
    checkHeight,
    onEach(Person::getMedicalConditions, checkMedicalCondition)
);
```

### Extensibility

One thing that's kind of frustrating about Java's OO approach to API design is you're kind of stuck with what you get out of the box. `Optional`, for example, has an `ifPresent` method, but not an `ifAbsent`, and can't be turned into a 'Stream'.

These are coming with Java 9, but that's kind of the point: I don't want to be dependent on an updated release for simple use-case scenarios like this. I'll build my own static methods to provide that functionality, but then they look out of place next to using the API as the author intended.

That's one advantage of building an API out of static methods: it allows augmentation of the standard API without being inconsistent.

So, let's look at an example. We're now validating the Fast-Track queue, which allows people who spent an extra £40 on their entrance ticket to jump queues. For this queue, people will fail validation if they don't have a Fast-Track ticket:

```java
Validator<Person, String> canRide = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    rejectIf(person -> !person.getTicket().isFastTrack(), "You need a Fast Track ticket"),
    onEach(Person::getMedicalConditions,
           rejectIf(DangerousConditions::contains, 
                    "It is dangerous to ride when you suffer a condition"))
);
```

Well, that's all well and good, but I'm really not a fan of that third condition there. The problem is here:

```java
Validator<Person, String> canRide = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    "!!pink!!"rejectIf"!!end!!"(person -> "!!blue!!"!"!!end!!"person.getTicket().isFastTrack(), "You need a Fast Track ticket"),
    onEach(Person::getMedicalConditions,
           rejectIf(DangerousConditions::contains, 
                    "It is dangerous to ride when you suffer a condition"))
);
```

That negation is very, very easy to overlook. The spurious presence or absence of a negation bang is one of my top reasons for misreading code and facepalmworthy automated test failures. It would be a ton nicer if instead we could say:

```java
Validator<Person, String> canRide = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    acceptIf(person -> person.getTicket().isFastTrack(), "You need a Fast Track ticket"),
    onEach(Person::getMedicalConditions,
           rejectIf(DangerousConditions::contains, 
                    "It is dangerous to ride when you suffer a condition"))
);
```

Then, instead of an awkward double negation, we express our requirement far more straightforwardly. The only problem being: there is no `acceptIf` on our library. 

Don't worry, it's there now: this is just a demonstrative hypothetical.

So, we go look at the implementation of `rejectIf`:

```java
public static <T, E> Validator<T, E> rejectIf(Predicate<T> test, E error) {
    return t -> test.test(t) ? Stream.of(error) : Stream.empty();
}
```

So we know what sort of signature we need. We don't even need to look at those internals. If we want to implement our `acceptIf`, it's pretty straightforward:

```java
public static <T, E> Validator<T, E> acceptIf(Predicate<T> test, E error) {
    return rejectIf(test.negate(), error);
}
```

But wait a moment. Let's look at those internals again. We're returning a function of `T` to a `Stream<E>`, and defining our return type as a `Validator<T, E>`. Didn't we say earlier that a Validator is a function of `T` to a `Result<T, FailedValidation<T, E>>`?

Yes, we did.

### You'll Never Believe This One Weird Trick With Functional Interfaces

Let's take a look at the definition of `Validator`:

```java
@FunctionalInterface
public interface Validator<T, E> extends Function<T, Result<T, FailedValidation<T, E>>> {

    default Result<T, FailedValidation<T, E>> apply(T item) {
        LinkList<E> errors = LinkLists.of(validate(item).collect(toList()));
        return errors.read(
                (x, xs) -> Result.failure(new FailedValidation<>(item, cons(x, xs))),
                () -> Result.success(item)
        );
    }

    Stream<E> validate(T item);
}
```

The first point to make here is that a `FunctionalInterface` is *not a Function*. It's slightly annoying at the best of times to take an argument of a `Function` and have to do this:

```java
public String doThing(Function<String, String> f, String s) {
    return f.apply(s);
}
```

instead of:

```java
public String doThing(Function<String, String> f, String s) {
    return f(s);
}
```

And whilst I think that's something which could, theoretically, be done in a principled way in a future version of Java, the point is that a `Function` is not the same thing as a function. It's an interface, and interfaces have methods. 

But it's a `@FunctionalInterface`, which means it has a single method, right? Nope. It means it has a single *abstract* method. We can have concrete methods on interfaces now.

`Validator` is a functional interface, which means it's an interface with one *non-default* method. That means you can define it as a lambda which matches the signature of `validate`. It extends `Function` with a default `apply`, which means you get `apply` (expressed in terms of `validate`) for free.

What this means is that *as long as the receiving code is expecting a `Validator`*, you can provide a lambda and you'll get something with that lambda as `validate`, with that implementation of `apply` for free. Furthermore, if you *provide* a `Validator` to something expecting a `Function`, it'll use the implementation of `apply`. For example:

```java
public Stream<Sprocket> wellFormedSprockets(
    Stream<Sprocket> sprockets) 
{
    return sprockets
            .map(compose(sprocket -> sprocket.isBroken() 
                ? Optional.of("No good!")
                : Optional.empty()))
            .flatMap(Result::successes);
}
```

Here, we're composing a single `Validator` simply because we know that `compose` accepts *some* (and that could be one or zero) `Validator`s and returns a `Validator`, so we can just give it a lambda and get a `Validator` (with our lambda implementing `validate`) out. `map` expects a `Function`, so it calls `apply` on the `Validator`.

OK, so that's cool. There's often an important distinction between things that are cool, and things that are good ideas. Where does this fall?

To answer that, it's worth going deeper into what we're trying to do with a `Validator`.

### How does validation *work*?

So, we have a thing, and we want to validate that thing, and we have a rule for validating that thing. If the thing fails the rule, we get an error. 

We might have multiple rules, in which case we could potentially have multiple errors.

So, we're talking between zero and many errors.

If there are zero errors, that's a success (of the item). If there are any errors, that's a failure (of the item and all errors).

This decision as to whether it's a success or a failure, and how to package the output, can be made at the top level after all checks are run. There's little point doing it before that: all the sub-checks might as well just give us a source of errors. That could be a `Collection`, or it could be a `Stream`, and we should choose whichever is easier to compose (which is a `Stream`).

So, when we're building a `Validator`, we *could* do it by combining a number of providers of `Stream`s of errors, and the end result to be a function which composes them and turns them into either a `Success` or a `Failure`. 

We *could* also do it by calculating the end result each time, and combining them with something like:

```java
public static Result<T, FailedValidation<T, E>> combine(
    Result<T, FailedValidation<T, E>> first,
    Result<T, FailedValidation<T, E>> second)
{
    return first.either(
        success -> second;
        failure -> second.either(
            success -> first,
            failure -> new FailedValidation(
                first.item, 
                concat(first.errors, second.errors)
            )
        )
    );
}
```

But there's no need to do so, and it gets complicated when it comes to validating subparts. Let's remind ourselves where we started:

```java
Validator<Person, String> canRide = compose(
    rejectIf(person -> person.getHeight() < 120, "You must be 1m20 tall to ride"),
    rejectIf(person -> person.getHeight() > 210, "You must be under 2m10 to ride"),
    onEach(Person::getMedicalConditions,
           "!!pink!!"rejectIf(DangerousConditions::contains,"!!end!!" 
                   "!!pink!!" "It is dangerous to ride when you suffer a condition")"!!end!!")
);
```

The highlighted section *is a `Validator`*, but it's a `Validator` of `MedicalCondition`s, not of `Person`s. How do we compose a `Result<MedicalCondition, FailedValidation<MedicalCondition, String>>` with a `Result<Person, FailedValidation<Person, String>>`?

The answer is: we don't really care. We care about the errors, we don't care what they're attached to - not until we get to the top level. 

Given the choice between getting all the errors and then working out the result, and working out the result each time and then composing, the former seems both preferable and easier.

### A Validator *is* a `Function<T, Stream<E>>`

If we think of a validator as a source of errors on a given input, it makes composition easy to understand:

```java
@SafeVarargs
public static <T, E> Validator<T, E> compose(Validator<T, E>... validators) {
    return t -> Arrays.stream(validators).flatMap(v -> v.validate(t));
}
```

It makes reaching-into easy to understand:

```java
public static <T, S, E> Validator<T, E> onEach(
    Function<T, Iterable<S>> seqGetter, 
    Validator<S, E> innerValidator) 
{
    return t -> StreamSupport
        .stream(seqGetter.apply(t).spliterator(), false)
        .flatMap(innerValidator::validate);
}
```

And - well, it makes sense from a conceptual level too. A `Validator` *is* a source of errors: we know it's a viable way of representing that from our initial implementation before we started getting fancy:

```java
public static List<String> reasonsYouCantRide(Person person) {
    List<String> reasons = new ArrayList<>();
    if(person.getHeightInCm() < 120) {
        reasons.add("You must be this tall to ride");
    }
    if(person.getHeightInCm() > 210) {
        reasons.add("You must be under this height to ride");
    }
    if (person.getMedicalConditions()
                  .stream()
                  .anyMatch(DangerousConditions::contains)) {
        reasons.add("It is dangerous to ride when you suffer a condition");  
    }
    return reasons;
}
```

We'd like it to be easier to construct more context than this. That's what the `Validation` library gave us. The model, however, is sound. We only want to be able to put a `T` in and get a `Result` out at the top level, and the rest of the time think about what we *actually* care about.

...It feels like this has gone a little off the rails (a *major* problem for a rollercoaster; a lesser one for a blogpost). What were we talking about? `@FunctionalInterface` and extensibility. 