---
layout: post
title: Refactoring towards a Functional Style
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
Yesterday, I refactored a method. 

Nothing unusual about that - we refactor code constantly. Code is, after all, better described as something grown than something built, and a large part of gardening is keeping the weeds in check. Normally, I wouldn't have given it a second thought.

What was unusual, though, was this was my first time pairing with Sarah, who's relatively new to Java 8 constructs like Optionals. Pairing with someone new often leads to more discussion of what's being done and why, which can provoke some interesting reflections.

As we stepped through the refactorings, I noticed a few simple pressures were guiding us towards a functional approach. Each one only made a small, incremental improvement. Together, they had a huge effect on the code.
<!--more-->

Here's the original code:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    Optional<ResponseWithMaybeDeal> responseWithDeal1;
    if (dealIdFromResponse.isPresent()) {
        responseWithDeal1 = dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                Optional<ResponseWithMaybeDeal> responseWithDeal;
                if (deal.isPresent()) {
                    responseWithDeal = Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } else {
                    responseWithDeal = Optional.empty();
                }
                return responseWithDeal;
            });
    } else {
        responseWithDeal1 = Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
    return responseWithDeal1;
}
```

My first impression: well, I can trace through that and understand what's going on, but it's a little hairy. Let's see if we can smooth it out a bit.

#### PRINCIPLE 1: Favour early-return over single-return.

The first thing I noticed was this:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    "!!pink!!"Optional<ResponseWithMaybeDeal> responseWithDeal1;"!!end!!"
    if (dealIdFromResponse.isPresent()) {
        "!!pink!!"responseWithDeal1 ="!!end!!" dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                "!!blue!!"Optional<ResponseWithMaybeDeal> responseWithDeal;"!!end!!"
                if (deal.isPresent()) {
                    "!!blue!!"responseWithDeal ="!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } else {
                    "!!blue!!"responseWithDeal ="!!end!!" Optional.empty();
                }
                "!!blue!!"return responseWithDeal;"!!end!!"
            });
    } else {
        "!!pink!!"responseWithDeal1 ="!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
    "!!pink!!"return responseWithDeal1;"!!end!!"
}
```
Here we have two examples of the single-return style, one in the method itself and one in a lambda contained within the method. Arguments exist as to which of single-return and early-return style is more readable – personally, I find that tracking changes through mutable variables like this is harder to reason about than just returning values when you have them. Returning rather than assigning gives us:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    Optional<ResponseWithMaybeDeal> "!!unused!!"responseWithDeal1"!!end!!";
    if (dealIdFromResponse.isPresent()) {
        return dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                Optional<ResponseWithMaybeDeal> "!!unused!!"responseWithDeal"!!end!!";
                if (deal.isPresent()) {
                    return Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } else {
                    return Optional.empty();
                }
                return "!!error!!"responseWithDeal"!!end!!";
            });
    } else {
        return Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
    return "!!error!!"responseWithDeal1"!!end!!";
}
```
That's reassuring, we have compile errors on the original return statements as they're unreachable, and the variables are unused. It's always nice when your IDE confirms that you've hit all the cases. Get rid of those lines and we get:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    if (dealIdFromResponse.isPresent()) {
        return dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                if (deal.isPresent()) {
                    return Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } else {
                    return Optional.empty();
                }
            });
    } else {
        return Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
}
```
#### PRINCIPLE 2: Favour if-expressions over if-statements

The next thing I noticed was this:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    "!!pink!!"if"!!end!!" (dealIdFromResponse.isPresent()) {
        "!!pink!!"return"!!end!!" dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                "!!blue!!"if"!!end!!" (deal.isPresent()) {
                    "!!blue!!"return"!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } "!!blue!!"else"!!end!!" {
                    "!!blue!!"return"!!end!!" Optional.empty();
                }
            });
    } "!!pink!!"else"!!end!!" {
        "!!pink!!"return"!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
}
```
We have two `if` statements here, with both `if` and `else` clauses, each of which returns immediately. These can be replaced with `if`-expressions:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return (dealIdFromResponse.isPresent()) 
        ? dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                return deal.isPresent() 
                    ? Optional.of(new ResponseWithMaybeDeal(bidResponse, deal))
                    : Optional.empty();
            }) 
        : Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
}
```
Is that prettier than the previous case? Is it clearer? 

It's not helped by the syntax decay from keywords to ternary symbology. Writing code with ternaries is dangerous because it's easy to forget to structure code in an easily decomposable way.  Readability and aesthetics are always in the eye of the beholder, and are heavily influenced by experience with different paradigms.

We now have something that's slightly terser. More importantly, this change *advertises something about the code*. More can happen in an `if`-statement than an `if`-expression: you can modify variables, call side-effecty `void` methods and so on. Making this an `if`-expression advertises that all we're doing is returning one of two things.

It's a more functional way of describing what the code's doing. I'm not *making* the code more functional; I'm just *exposing* the functional properties of the code which already existed. Whether you think this is a good thing in and of itself is up to you, but – as you'll see – these changes make it easier to spot further functional refactorings down the line.

#### PRINCIPLE 3: Don't treat Optionals like nulls

The next thing I noticed was:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return "!!pink!!"(dealIdFromResponse.isPresent())"!!end!!" 
        "!!pink!!"?"!!end!!" dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                return "!!blue!!"deal.isPresent()"!!end!!" 
                    "!!blue!!"?"!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, deal))
                    "!!blue!!":"!!end!!" Optional.empty();
            }) 
        "!!pink!!":"!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
}
```
`Optional`s are a really important addition to Java 8. Unfortunately, the general introduction to `Optional`s - that they're a better way of addressing the problems we get with `null` – tends to result in `Optional`-handling code looking like `null`-handling code at first. Our method is currently a good example of that.

`Optional`s don't just exist to represent the possibility of absence. Viewing them as that means you miss the real benefit: safety.

Safety, because `Optional`s provide methods which force you to address the absent case. `Optional` provides 3 ways of getting a `T` out of an `Optional<T>`: `Optional::orElse`, `Optional::orElseGet`, and `Optional::orElseThrow`.  Each of these requires you to describe the result you want when the thing you know might not be there turns out to not be there.

Technically, it also provides `Optional::get`, which allows you access to the Java 8 version of `NullPointerException`s if you really want them. This should be considered an alias to `Optional.orElseThrow(BadAtProgrammingException::new)`. 

The blue section here is easiest to refactor, from this:

```java
Optional<UnrulySSPDeal> deal = findDeal(dealId);
return deal.isPresent() 
    ? Optional.of(new ResponseWithMaybeDeal(bidResponse, deal))
    : Optional.empty();
```
To this:

```java
Optional<UnrulySSPDeal> deal = findDeal(dealId);
return deal.map(__ -> new ResponseWithMaybeDeal(bidResponse, deal));
```
This is a little awkward, because we're mapping over an `Optional` but not using its contents, which... isn't really a mapping. An alternative implementation is this:

```java
Optional<UnrulySSPDeal> maybeDeal = findDeal(dealId);
return maybeDeal.map(deal -> new ResponseWithMaybeDeal(bidResponse, Optional.of(deal));
```
Here we're unwrapping and then re-wrapping the deal in an `Optional`, which means we can inline `findDeal`. So our whole method now looks like this:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return "!!pink!!"(dealIdFromResponse.isPresent())"!!end!!"
        "!!pink!!"?"!!end!!" dealIdFromResponse
            .flatMap(dealId -> 
                findDeal(dealId).map(deal -> new ResponseWithMaybeDeal(bidResponse, Optional.of(deal))))
        "!!pink!!":"!!end!!" Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
}
```
The pink section is also easy to refactor, as we're already doing a mapping operation over it: we know if the deal isn't present, we'll have an `Optional.empty()`. So we can refactor this too:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return dealIdFromResponse
        .flatMap(dealId -> 
            of(findDeal(dealId).map(deal -> new ResponseWithMaybeDeal(bidResponse, of(deal)))))
        .orElseGet(() -> of(new ResponseWithMaybeDeal(bidResponse, empty())));
}
```
There are a few important things to notice about this change:

* I've statically imported Optional.of and Optional.empty for the blogpost to prevent word wrap. I'm not a fan of statically importing Optional.of as the loss of context diminishes meaning. 
* I've used `orElseGet` with a lambda instead of just `orElse` with the value to prevent creating unnecessary objects. Generally, `orElseGet()` should be favoured over `orElse()` unless you already have an instance to return. In my opinion, little would be lost if the only way to get a `T` out of an `Optional<T>` was `orElseGet()`.
* In order to use `Optional`'s branching, we have to wrap our return values in more `Optional`s.

#### PRINCIPLE 4: Think outside the box

At this point we started asking ourselves: this wrapping in `Optional`s is clunky, why are we doing that? We're doing that in order to return an `Optional<ResponseWithMaybeDeal>`, because we're in a situation where we can return `Optional.empty()`. Where's the empty case?

Because of the way we're composing nested optionals, it's difficult to spot in this version of the code, compared to the original. The empty case is when we have a deal id on a response, but we can't find a matching deal. So we're doing two things in this method: augmenting with the deal, and filtering out invalid deal ids.

Functions should do one thing.

So, we changed what the function does, and moved the filtering outside. If we just pair the response to the corresponding deal (when we can find one), we no longer have a reason to wrap in an `Optional`, allowing us to go from this:

```java
private "!!pink!!"Optional"!!end!!"<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return dealIdFromResponse
        .flatMap(dealId -> 
            "!!pink!!"of"!!end!!"(maybeDeal.map(deal -> new ResponseWithMaybeDeal(bidResponse, of(deal))));
        })
        .orElseGet(() -> "!!pink!!"of"!!end!!"(new ResponseWithMaybeDeal(bidResponse, empty())));
}
```
To this:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return dealIdFromResponse
        .flatMap(dealId -> 
            findDeal(dealId).map(deal -> new ResponseWithMaybeDeal(bidResponse, Optional.of(deal))))
        .orElseGet(() -> new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
}
```
We could have made this simplification without having gone through the previous steps, but the path we were going down led us to question whether or not we were doing the right thing.

#### PRINCIPLE 5: Repeated patterns are usually liftable

The next thing we noticed was:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    return dealIdFromResponse
        .flatMap(dealId -> 
            findDeal(dealId).map(deal -> "!!pink!!"new ResponseWithMaybeDeal(bidResponse,"!!end!!" Optional.of(deal))))
        .orElseGet(() -> "!!pink!!"new ResponseWithMaybeDeal(bidResponse,"!!end!!" Optional.empty()));
}
```
We're returning a ResponseWithMaybeDeal from this method, and we're creating it on both paths. So we can simplify that by lifting that part out – first by extracting the return value into a variable:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    ResponseWithMaybeDeal responseWithMaybeDeal = dealIdFromResponse
        .flatMap(dealId -> findDeal(dealId).map(deal -> new ResponseWithMaybeDeal(bidResponse, Optional.of(deal))))
        .orElseGet(() -> new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    
    return responseWithMaybeDeal;
}
```
And then pulling the construction up to the top level: 

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    Optional<UnrulySSPDeal> maybeDeal = dealIdFromResponse
        .flatMap(dealId -> findDeal(dealId)"!!blue!!".map(deal -> Optional.of(deal))"!!end!!")
        "!!pink!!".orElseGet(() -> Optional.empty())"!!end!!"";

    return new ResponseWithMaybeDeal(bidResponse, maybeDeal);
}
```
Even when that's done, the pink code stuck out. orElseGet() returns an empty `Optional`? Why would we do that instead of just taking the `Optional` we're calling it on? 

That's because after flatmapping, we have an `Optional<Optional<UnrulySSPDeal>>`, and we need an `Optional<UnrulySSPDeal>`: we have two layers of `Optional` wrapping. This isn't a side-effect of working with `Optional`s, it's deliberately introduced in the blue section, which is now kinda redundant. So we can refactor that to:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    Optional<UnrulySSPDeal> maybeDeal = dealIdFromResponse
        .flatMap(dealId -> findDeal(dealId));

    return new ResponseWithMaybeDeal(bidResponse, maybeDeal);
}
```
Which can then be inlined and method-reference-extracted to:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<UnrulySSPDeal> maybeDeal = getDealIdFromResponse(bidResponse).flatMap(this::findDeal);
    return new ResponseWithMaybeDeal(bidResponse, maybeDeal);
}
```
And, finally, it feels like we're done. First get a `maybeDeal` (by getting the deal id, and then looking up the deal, assuming they both exist), and then we construct a `ResponseWithMaybeDeal` with the `BidResponse` and the `maybeDeal`. It really does just do what it says on the tin.

#### SUMMING UP

Before we go, let's just reflect on how far we came - we started with this:

```java
private Optional<ResponseWithMaybeDeal> matchResponseToDeal(BidResponse bidResponse) {
    Optional<String> dealIdFromResponse = getDealIdFromResponse(bidResponse);

    Optional<ResponseWithMaybeDeal> responseWithDeal1;
    if (dealIdFromResponse.isPresent()) {
        responseWithDeal1 = dealIdFromResponse
            .flatMap(dealId -> {
                Optional<UnrulySSPDeal> deal = findDeal(dealId);
                Optional<ResponseWithMaybeDeal> responseWithDeal;
                if (deal.isPresent()) {
                    responseWithDeal = Optional.of(new ResponseWithMaybeDeal(bidResponse, deal));
                } else {
                    responseWithDeal = Optional.empty();
                }
                return responseWithDeal;
            });
    } else {
        responseWithDeal1 = Optional.of(new ResponseWithMaybeDeal(bidResponse, Optional.empty()));
    }
    return responseWithDeal1;
}
```
And, through a series of tiny steps, each improving the code in its own right, ended up with this:

```java
private ResponseWithMaybeDeal matchResponseToDeal(BidResponse bidResponse) {
    Optional<UnrulySSPDeal> maybeDeal = getDealIdFromResponse(bidResponse).flatMap(this::findDeal);
    return new ResponseWithMaybeDeal(bidResponse, maybeDeal);
}
```

You may argue that one or two of the steps weren't an improvement in style, in and of themselves. I'm not sure I'd agree, but I can see how you might think that. However, that's not the point. Each of the steps were part of a gradual progression towards the final result - an implementation which is clearly, objectively better than the original. 

These refactorings aren't just changes in style - they're changes in form, replacing broad constructs with more restrictive ones. Each application is therefore a simplification: being *able* to apply them shows that our code is simpler than its original structure implies. Repeated applications of those refactorings took us to the simplest possible form.