---
layout: post
title: Optional.get() considered harmful
author: Tom Johnson
published: true
---

> I call it my billion-dollar mistake. It was the invention of the null reference in 1965... **My goal was to ensure that all use of references should be absolutely safe, with checking performed automatically by the compiler**. But I couldn't resist the temptation to put in a null reference, simply because it was so easy to implement. This has led to innumerable errors, vulnerabilities, and system crashes, which have probably caused a billion dollars of pain and damage in the last forty years.

*-- Tony Hoare*

Nulls are terrible. They're dangerous and sneaky and they're [why Java's type system is unsound](http://io.livecode.ch/learn/namin/unsound). Ideally, we'd never use them, but we can't do much about twenty years of libraries which might return nulls. At least we can try to stop returning them in our own APIs, because Java 8 gave us `Optional`s.

What's an `Optional`? It's a data type which represents either a value, or... not a value. This allows us to represent the possibility of an absence of the value in the type system. So, instead of code like this:

```java
public static void helloKitty(Cat kitty) {
    if(kitty != null) {
        System.out.println(kitty.meow());
    }
}
```

We can write code like this:

```java
public static void helloKitty(Optional<Cat> kitty) {
    if(kitty.isPresent()) {
        System.out.println(kitty.get().meow());
    }
}
```

The latter code is, to my mind, indisputably better than the former. The possibility of nullity is encoded in the types, and we can't do anything to the cat without making a conscious decision to remove it from the `Optional`.

Intent is clearer. Mistakes are less likely. These are good things.

That said, **don't write code like this**. Just because it's better than the null-exposed version doesn't make it *good*.

So, what's wrong with it? It's right here:

```java
public static void helloKitty(Optional<Cat> kitty) {
    if(kitty.isPresent()) {
        System.out.println(kitty."!!pink!!"get()"!!end!!".meow());
    }
}
```

### One of these things is not like the other

There are four methods on an `Optional<T>` that return a `T`. They are:

 - `get()`
 - `orElse(T t)`
 - `orElseGet(Supplier<T> t)`
 - `orElseThrow(Supplier<? extends Exception> ex)`

All of these specify how to behave when a `T` is not present in an `Optional<T>`. All of them, that is, apart from `get`. It makes sense to require a specification of how to behave when the `Optional` is empty: the role of `Optional` is to represent that possibility.

Simply put: the only time it is safe to call `Optional.get()` is when we know it is *not* empty, and in those situations *it shouldn't be an `Optional`*.

So what happens when you call `get()` on an empty `Optional`? You get a `NoSuchElementException`: Java 8's sick joke version of a `NullPointerException`.

### There is a better way

If we take the code above, we can rewrite it from:

```java
public static void helloKitty(Optional<Cat> kitty) {
    if(kitty.isPresent()) {
        System.out.println(kitty.get().meow());
    }
}
```

to:

```java
public static void helloKitty(Optional<Cat> kitty) {
    kitty.ifPresent(cat -> System.out.println(cat.meow()));
}
``` 

The latter is safer than the former. You can't accidentally invert the condition or comment it out and blow up on the get, because it's encapsulated in the `Optional` itself. The code that handles the `Cat` is only ever invoked when there's a `Cat` to invoke it on.

Importantly, it's also nicer. It's shorter and more direct. The reason that's important is *you don't even have the aesthetic excuse* for using the check-and-get pattern.

Depending on taste and context, we could also rewrite it as:

```java
public static void helloKitty(Optional<Cat> kitty) {
    kitty.map(Cat::meow)
         .ifPresent(System.out::println);
}
```

This is a little longer, but it's more declarative and composable. If we had more steps of digging into structure, or we wanted to do some processing of the cat's distressed yelp prior to printing it, then this structure would scale better than building a large lambda. 

If the operations we want become more complex - say, for example, we want to hear all forms of the poor moggy's anguish - we can also consider the following:

```java
public static void helloKitty(Optional<Cat> kitty) {
    kitty.ifPresent(ThisClass::listen);
}

private static void listen(Cat kitty) {
	System.out.println(kitty.meow());
	System.out.println(kitty.hiss());
}
```

### We know it's always there

Occasionally, you might find yourself in a situation where either a presence check or providing an alternate in case of absence is overkill, because you know the `Optional` can't be empty. In that case you should refactor code like this:

```java
public static void helloKitty(Optional<Cat> kitty) {
    System.out.println(kitty.get().meow());
}
```

to this:

```java
public static void helloKitty(Cat kitty) {
    System.out.println(kitty.meow());
}
```

`Optional` exists to represent the possibility of absence. If there's no such possibility, then we shouldn't be using an `Optional`, and we should push changes up to the calling method.

### We don't *know* it's there, but it's a bug if it isn't

Maybe you'll find yourself in a situation where the *code* doesn't guarantee the `Optional` is present, but the *domain* does. Then, you don't want to provide an alternative: you want to throw an error in case of absence. That's what `Optional.get()` does. In that situation, you should prefer to write this:

```java
public static void helloKitty(Optional<Cat> kitty) {
    System.out.println(kitty.get().meow());
}
```

Like this:

```java
public static void helloKitty(Optional<Cat> kitty) {
    Cat myKitty = kitty.orElseThrow(HaveYouSeenThisCatException::new);
    System.out.println(myKitty.meow());
}
```

The difference here is one of intent and communication. In the former case, it's not clear whether or not the failure case even occurred to the programmer. When an exception is raised, it's non-specific and doesn't provide any insight as to where the assumptions broke down. The latter case is clear, and provides appropriate mechanisms to detail exactly what went wrong.

The difference here is that `Optional.get()` throws *on accident*, because that's all it can do, whereas `Optional.orElseThrow()` throws *by design*, so if you *want* to throw, use the latter.

In general, `Optional.get()` should be considered an alias for `Optional.orElseThrow(BadAtJavaException::new)`.

### Streams!

One pattern I've seen a bit is turning a sequence of `Optional<T>`s into a sequence of `T`s, which can be done cleanly using `Stream`s:

```java
public static <T> List<T> extractValues(List<Optional<T>> maybes) {
    return maybes.stream()
                 .filter(Optional::isPresent)
                 .map(Optional::get)
                 .collect(Collectors.toList());
}
```

This is usually done as an operation inline on a stream of things, rather than being a standalone method, but that's the minimal illustrative sample. This pattern of `filter` then `get` is reasonably clear in its intent, but there's a better way:

```java
public static <T> List<T> extractValues(List<Optional<T>> maybes) {
    return maybes.stream()
                 .flatmap(Optional::stream)
                 .collect(Collectors.toList());
}
```

`Optional.stream()` converts an `Optional<T>` to a `Stream<T>`, with one element if it was present or none if it was absent. The only slight drawback is that it doesn't exist.

Well, it doesn't exist yet - it's being added to the API in Java 9. In the meantime, we can build our own version:

```java
public static <T> List<T> extractValues(List<Optional<T>> maybes) {
    return maybes.stream()
                 .flatmap(ThisClass::stream)
                 .collect(Collectors.toList());
}

public static <T> Stream<T> stream(Optional<T> maybe) {
	return maybe.map(Stream::of).orElseGet(Stream::empty);
}
```

This pattern comes up often enough that it's well worth extracting as a convenience until you've migrated to Java 9, and then it'll be easy to refactor to the API version.

### What else?

One thing that none of these patterns help with, though, is when the `if` block has an `else` clause. Sometimes dealing with these constructs is simple. For example:

```java
public static void helloKitty(Optional<Cat> kitty) {
    if(kitty.isPresent()) {
        System.out.println(kitty.get().meow());
    } else {
        System.out.println("I tawt I taw a puddy tat?");
    }
}
```

can be rewritten:

```java
public static void helloKitty(Optional<Cat> kitty) {
    String output = kitty.map(Cat::meow)
                         .orElse("I tawt I taw a puddy tat?");
    System.out.println(output);
}
```

But sometimes you want to do different things on the different paths:

```java
public static void helloKitty(Optional<Cat> kitty) {
    if(kitty.isPresent()) {
        System.out.println(kitty.get().meow());
    } else {
        LOGGER.error("I tawt I taw a puddy tat?");
    }
}
```

Here, it would be nice if we could rewrite it as:

```java
public static void helloKitty(Optional<Cat> kitty) {
    kitty.ifPresentOrElse(
        cat -> System.out.println(cat.meow()),
        () -> LOGGER.error("I tawt I taw a puddy tat?"));
}
```

Unfortunately, there's no `Optional.ifPresentOrElse()` method - but the good news is that's coming in Java 9 too. Again, in the meantime, we can roll our own:

```java
public static void helloKitty(Optional<Cat> kitty) {
    ifPresentOrElse(
        kitty, 
        cat -> System.out.println(cat.meow()),
        () -> LOGGER.error("I tawt I taw a puddy tat?"));
}

public static <T> void ifPresentOrElse(Optional<T> optional, Consumer<T> consumer, Runnable task) {
	optional.ifPresent(consumer);
	if(!optional.isPresent()) {
		task.run();
	}
}
```

### Summing up

So, to recap:

- `Optional`s exist to provide a safe, explicit alternative to `null`
- `Optional.get()` is not safe
- `Optional.get()` is not necessary
- When the unsafe-ness of `Optional.get()` is the behaviour you want, there is a better alternative: explicitly using `Optional.orElseThrow()`
- The world would be a better place without `Optional.get()` on the API
- **Don't use `Optional.get()`**
