---
layout: post
title: Failure is not Right
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

When talking about implementing a result type in functional programming languages, many people remark that this can be implemented using an `Either` datatype. For example, in Haskell, the definition of `Either` is:

```haskell
Either a b = Left a | Right b
```

All this means is an instance of `Either a b` is a `Left a`, or it's a `Right b`. This datastructure is applicable to many use cases: one of them is representing the union of success and failure. For the case where it represents success or failure, a handy mantra is "Failure isn't right".

What that means is: for an `Either a b`, the success type is `b` and the failure type is `a`. This is true for two reasons.

<!--more-->

### There are two hard problems in computer science

Cache invalidation, naming things, and off-by-one errors. Or so the joke goes.

Naming things is hard, especially when crossing abstraction layers. `Either` is an acontextual term, but success and failure have context. They have meaning. It's important for users of an `Either` to understand what it intended, and what it means, because confusing a success and a failure is, well, it doesn't do much good.

Whilst we could introduce a new, more contextual way of dealing with results, there are reasons not to. `Either` is a good abstraction for a whole set of problems, some of which don't want to be burdened with the supposition that one side is good, the other bad. I'm either going to have pizza or gammon-steaks for dinner: neither is fundamentally right or wrong. 

When you have a lack of meaning in an API, the next best thing you can do is ascribe meaning. Given we have a datastructure with two concepts - `Left` and `Right`: which should represent success, and which should represent failure?

Well, success means you got something right. So, `Right` it is. Where no meaning exists, we take meaning where we can find it: whatever acts as a mnemonic is better.

### Failure Can't Be Right

That's a marginally convincing reason, but there's a much more powerful reason. `Either` wouldn't work as a way of representing results nearly as well if successes were on the left and failures were on the right. At least, it wouldn't work so well in Haskell. And it all boils down to monads.

The really big gain from using `Either` as a result is monadic composition. When you have a series of operations, each taking an input and yielding an output, but which can fail, what you usually want to do is proceed along that series of operations until you hit one which fails, at which point you want to stop and return that error.

Monadic composition is a very clean way of implementing that concept. In Haskell, it would be easy to make `Either` a monad if it didn't already come like that for free. It's as simple as:

```haskell
instance Monad (Either a) where
  return = Right
  (Left x) >>= f = Left x
  (Right x) >>= f = f x
```

That's not a lot of code! In brief, this says we can create a "standard" `Either` by using the constructor `Right`, and we can apply a function to an `Either` using `>>=`. When we do, if it's a `Left`, we get the same `Left` out, and when it's a `Right`, we get the result of applying that function its value. Furthermore, what we get out is another `Either`, so we can apply more functions to it using the same convention, buiding a pipwline of operations. That sounds exactly like the model we want for sequencing operations which might fail.

Furthermore, it's abstracted over types. That means that we can put any sort of `Either` into it, regarldess of what types it's instantiated over. We're not actually interacting with the inner type (beyond applying `f` to it), so it's agnostic in terms of what's put in it.

Only thing is - it's abstracted over types in a particular way. A `Monad` takes *one* type parameter, and that's the type that we instantiate from and that we pass to bound functions. An `Either`, however, tales *two* type parameters. So which one do we want to treat monadically?

Well, `Success`, of course. The alternative would be starting with a `Failure` and continually trying things until we yield a `Success`, which... huh. That's not what we were trying to achieve, but I can certainly see times we might want to do that. Only, not as frequently as starting with a `Success` and performing operations to yield an end result, stopping if we hit a `Failure` on the way. But I digress.

The thing in Haskell is: it's not possible to declare an instance of `Monad` parameterised over the first type parameter of a type with two parameters. `Monad` takes one type argument, and you can partially apply the type constructor `Either` with the left parameter, but you can't partially apply a type parameter over later parameters. That's not how currying works.

So, in order to make `Either A B` a `Monad`, *it has to be* a `Monad B`.

That's why `Success` is Right. Not because of the aide-memoire, although that's convenient: because *it has to be* to get the behaviour we want.

### Java isn't Haskell

In Haskell, in order to make `Either` a `Monad`, we have to make it a `Monad` of the right type argument. But, of course, we could get the same behaviour over the left type argument if we implemented our own functions: as long as we knew what functions to call, it would work just as well. It wouldn't be an instance of the `Monad` typeclass, and so we wouldn't be able to take advantage of the abstractions over `Monad`, but maybe we don't care.

In Java, we don't have any typeclasses, so we don't have abstractions over them to take advantage of. Also, our type system also doesn't place any constraints on how we abstract over them by position. So the functional arguments for putting success on the right simply don't apply.

In Haskell, idiomatic code is abstract, using common functions over common datastructures, looking for mathematical isomorphisms to identify which class of well-understood problems the current task is.

In Java, idiomatic style is different. Partly because of weaker abstractions, but mostly because object-oriented style promotes well-defined, noun-based abstractions. We expect to convey meaning with our types: represent role, rather than implementation. Java's style tends towards being much more domain-driven, so the functions we want to use to interact with our results want to be living in a domain with terms like success, failure, and attempts. So just because a result may be *implemented* as an `Either`, that doesn't mean we have to call that type `Either`.

Maybe we'd be better off just calling it `Result`.

In that case, we don't need an aide-memoire as to which constructor gives us a success, because instead of choosing between `Left` and `Right`, we're choosing between `Success` and `Failure`.

Then we can build a toolkit of functionality which assumes the domain of a `Result` and not be worried about people "applying it incorrectly". We can not get hung up on it being a `Monad`, and interact with both `Success` and `Failure` as appropriate. Unlike in Haskell, we don't lose anything in the process, as the abstractions that motivated us to generalise in Haskell can't exist here.

Java isn't Haskell: nor is it Scala, or Python, or Javascript, or Rust. That's not to say we can't learn a lot from how other languages approach problems: we should totally do that, as they have some elegant solutions to problems that Java doesn't deal with well. But when we bring ideas across, we shouldn't just copy blindly: be aware of the motivations behind those conventions, the context of our destination, and let that guide what we take and what we change.

Maybe, sometimes, we'll even end up with something better in the end.
