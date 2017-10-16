---
layout: post
title: Typing Types
author: Tom Johnson
published: false
excerpt_separator: <!--more-->
---
Take a look at this interface:
```
interface SingleInstanceStore {
  SingleInstanceStore put(Object instance);
  <T> Optional<T> get(Class<T> type);
}
```
What is this? Why might you need it? And how would you go about implementing such a thing?

<!--more-->

This is a container of objects, which can hold at most one object of any given type.
When you provide it with a type, it then returns an instance of that type (or an
empty Optional).

Why might you want a container which can contain multiple types, but only one
instance of each type? Well, let's talk about the Minstrel type system.

### Concerns

Types in Minstrel can be straightforward data types, like `String`, object types
like `{ x: Number, y : Number }`, or function types like `[Number, Number] -> Number`.
But they can also have other concerns - for example, purity. We can declare a function
type like `pure [Number, Number] -> Number`.

Whether or not a function is pure is entirely orthogonal to its input and output
types. The purity of a custom function can be inferred purely from the purity of
the expressions it contains, and the assignment/subtyping rules around purity
(a known pure function may be used where impure functions are expected, but not
vice versa) are also independent of the function type.

On that basis, it's reasonable to model the type of such a function as the
product of its signature and its purity - say, an object with two separate fields.

That's just two examples of things we may care about enforcing in our type
system. We may also want to encode if a variable is a unique reference to an
object, or the dimensions of a physical quantity, or some  *domain-specific*
concept.

I refer to these concepts as *concerns*.

It's important to note that each concern is itself represented by a distinct
datatype with a distinct shape.
  * A data type is a unique symbol
  * A signature has a list of argument types and a return type
  * An interface is a map of field name to type
  * Purity is a two-state enum - known pure or not known pure
  * Physical dimensions are a map of dimension to exponent
  * And so on...

### Rules

In this model, a type is an aggregation of concerns, and a type system is a
combination of derivations (how we determine what the type of an expression is)
and rules (how we determine whether or not an operation is legal).

When we write a rule, we will be looking at (potentially) multiple concerns,
each of a distinct type. We know any given type will only have one value for
each concern, and whilst an individual rule will know what types it's dealing
with, the orchestration of (again, potentially) many rules won't.

Is this a sensible way to implement a type? It's too early for me to say, but
it sounds like the sort of thing we should at least be able to make
theoretically type-check.

### What's the type of a Type?

A Type is, under this model, a collection of concerns: either one or zero
instances of each of a collection of types, and the implementation of the type
system doesn't know what those types are (as those types come from inputs to it).

The thing that's tricky here is having our orchestrating code agnostic about
the types things inside it uses - we need a generic container which is
generically constrained by call-site.

That's where `SingleInstanceStore` comes in. It's a type-safe way of being able
to retrieve an (optional) instance of a class based purely on the input. It's
quite straightforward to implement in Java:

```
public class SingleInstanceStore {
    private final Map<Class<?>, Object> instances = new HashMap<>();

    public SingleInstanceStore put(Object o) {
        instances.put(o.getClass(), o);
        return this;
    }

    @SuppressWarnings("unchecked")
    public <T> Optional<T> get(Class<T> clazz) {
        return (Optional<T>) Optional.ofNullable(instances.get(clazz));
    }
}
```

It's easy to implement this in a way that type-checks because, bluntly, we
cheat. Our internal store isn't typed, and we cast our way to success by baldly
asserting that we know what we're doing. Of course, it's entirely possible we
*don't* know what we're doing, and we can suppress warnings away with all sorts
of shenanigans:

```
public class BadHeterogenousMap {
    private final Map<String, Object> instances = new HashMap<>();

    public BadHeterogenousMap put(String key, Object value) {
        instances.put(key, value);
        return this;
    }

    @SuppressWarnings("unchecked")
    public <T> Optional<T> get(String key) {
        return (Optional<T>) Optional.ofNullable(instances.get(key));
    }
}
```

This is another attempt at a heterogenous store, but it's one that can be
misused - the following self-contradictory code compiles just fine:

```
BadHeterogenousMap hmap = new BadHeterogenousMap();
hmap.put("Hello", "World");

Optional<String> iThinkThisIsAString = hmap.get("Hello");
Optional<Integer> iThinkThisIsANumber = hmap.get("Hello");
```

What if we wanted to do this in a language which doesn't allow you to circumvent
the type system however you want? Is it possible to implement this in a way
which is actually type-safe? What does a type system that enables that look like? 
