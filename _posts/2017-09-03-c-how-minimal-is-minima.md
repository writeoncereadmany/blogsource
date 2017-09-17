---
layout: post
title: How Minimal is Minima?
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

This is the third in a series of posts on the [Minima language](https://github.com/writeoncereadmany/minimalang). [Here's the first](https://writeoncereadmany.github.io/2017/09/a-minima),
and [here's the second](https://writeoncereadmany.github.io/2017/09/b-overloading-in-minima).

One of the motivating factors behind Minima is to make it as small as possible,
so that when it comes time to add features to it, those changes are easy.

But Minima isn't as small as possible. It's quite small, but some of its
features are implementable in terms of other features.

### Variables

Let's start with variables. We need to be able to access variables, but we have
two ways of defining them: with `is` declarations, and as function parameters.

We can't really get rid of function parameters, but we can rewrite any code
which uses `is` to use function parameters instead. For example:
```
greet is [name] => (
  start is "Hello, ",
  print[start:concat[name]]  
)
```
We could eliminate the variable `start` by inlining it, but for demonstrative
purposes, we want to give it a name. So instead we can do:
```
greet is [name] => (
  ([start] => print[start:concat[name]])["Hello, "]
)
```

### Grouping

Let's say we want to write a function which prints three things:
```
visit is [name] => (
  print["Hello, ":concat[name]]
  print[name:concat[", may I take your coat?"]
  print["Goodbye, ":concat[name]]  
)
```

We can do that without grouping, by creating a function which takes and ignores
three parameters, and immediately invoking it with our three side-effecting
expressions:
```
visit is [name] => (
  ([ignore1, ignore2, ignore3] => SUCCESS)[
    print["Hello, ":concat[name]],
    print[name:concat[", may I take your coat?"]],
    print["Goodbye, ":concat[name]]
  ]  
)
```

This achieves both purposes of grouping: allowing side effects, and creating
variables bound to locally evaluated values.

It's worth noting that whilst this obviates the need for sequencing expressions
in a group, we still do need parentheses for precedence - otherwise, we'd be
trying to invoke `SUCCESS` instead of our locally declared function.

An expression like: `apply is [a, b] => a[b]` can be interpreted in two ways:
either as `(apply is [a, b] => a)[b]`, or as `apply is ([a, b] => a[b])`. Here,
we clearly mean the former, but that's only obvious as a reader from context.

We can apply various precedence rules: access binds the most tightly, then
invocation, then implication and then assignment the most weakly - and that will
usually do what we want. But sometimes we want invocation to apply after
implication, and for that we need control of precedence.

This means we can't entirely get rid of grouping, at least not with this
syntax - but we could downgrade it to only taking a single expression: ie
regular parenthesisation.

### Objects

Objects are how we build larger data structures out of smaller ones. For example,
if we want to represent a 2D vector, and we had access to both a `square` and
a `sqrt` function:

```
vector is { x : 2, y : 5 }

length is [vector] => (
  x is vector:x,
  y is vector:y,
  sqrt[square[x]:plus[square[y]]]
)  

print[length[vector]]
```

But we can also represent that with a function:

```
vector is [f] => f[2, 5]

length is [vector] => (
  calc is [x, y] => sqrt[square[x]:plus[square[y]]],
  vector[calc]
)

print[length[vector]]
```

That's just one way of interacting with a function datatype. We may
prefer to do this:

```
vector is [f] => f[2, 5]
getX is [x, y] => x
getY is [x, y] => y

length is [vector] => (
  x is vector[getX],
  y is vector[getY],
  sqrt[square[x]:plus[square[y]]]
)

print[length[vector]]
```

This is just another way of binding the values together. It's interesting to
note how instead of performing operations *on* the vector, we give
operations *to* the vector - which is a bit counterintuitive with how we usually
use functions, but is surprisingly analagous to the field access. Just compare
`vector:x` to `vector[getX]` - it's basically the same semantics.

This approach has its problems, though.

Particularly, there's no association of name to position - we could easily
confuse ourselves if we were to do something like this:

```
vector is [f] => f[2, 5]

height is vector[[h, w] => h]
```

Our *intention* was that width is the x-component and height is the y-component,
and we list those components in the order x, y. But we don't have any way of
enforcing that, or even documenting it well.

Where an object is a mapping of *name* to value, here it's just a mapping of
*position* to value, so contextual mistakes like this are easy to make.

Also, this is all well and good when we're concerned about representing a concise
bundle of data like a 2D point, but it quickly becomes unwieldly when dealing
with something which has a lot of fields - such as a rich object like a number,
with many methods.

### Polymorphism and abstraction

There's a bigger problem, too: we don't just want to represent objects as a
fixed set of fields/methods. We want to enable polymorphism - for example,
`print` is a function which should be able to render anything with a `show`
method. Function datatypes don't provide an obvious approach to this.

What we could do, instead, is build a datatype that is just a mapping from
name to value, build some useful functions around it, and use that instead.
Like, well, a map.

At this point I'm going to skip ahead and make two assertions: firstly, that's
something we can do, and secondly, it ends up being a lot more verbose. The best
case scenario is something like this:

```
vector is mapOf["x", 2, mapOf["y", 5, empty]]

length is [vector] => (
  x is get[vector, "x"],
  y is get[vector, "y"],
  sqrt[square[x]:plus[square[y]]]
)
```

Effectively, we can build an object system in our code. It doesn't *feel* like
an object system, but it gives us the capabilities we need, albeit clunkily. In
fact, that's pretty much what the Java implementation of Minima does.

### Numbers

We don't need numbers in our language either. We can build our own, using just
functions. Let's start with the natural numbers: counting numbers, starting
with zero and going up by one.

A number can be defined as being either zero, or the successor of another
number. Let's define a number which represents how many times an operation will
be repeated:

```
zero is [s, z, acc] => z[acc]
succ is [pred] => [s, z, acc] => pred[s, z, s[acc]]

three is succ[succ[succ[zero]]]

bangs is three[
  [acc] => acc:concat["!"],
  [acc] => acc,
  ""
]

print[bangs]
```

This prints three bangs. Let's get more adventurous: addition!

...wait, no, let's not, this is getting dangerously indulgent now. Suffice it
to say at this point, whilst it's possible to represent numbers - or, for that
matter, any data type - this way, it's not very practical. I think it's time
to sum up a bit.

### Summing up a bit

Ultimately, of Minima's features, we can represent most of them using functions.
We can create datatypes, remove the need for traditional variables, and remove
the need to group multiple expressions into one. What we do need - the tools we
keep going back to - are those three fundamental operations:
  * Define a function
  * Invoke a function
  * Read a variable

If we wanted a truly minimal language, that would be it. There's a name for
that language: the lambda calculus. Anything you can express in Minima can also be
expressed in the lambda calculus: for that matter, anything you can express in
any language can also be expressed in the lambda calculus.

So why do we need any other languages? Because the lambda calculus is a pain in
the ass to work with. Every time we remove a feature from Minima, the code ended
up worse. A lot worse.

Removing the ability to bind variables or group expressions twists our code
into awkward contortions that don't logically flow. It looked pretty bad
in small snippets, but having to introduce nested components just for access to
variables breaks down incredibly quickly as program size increases. Try writing
a program which defines four functions, each in terms of the prior, using
parameters as your only variables, and you'll see what I mean.

We can do some interesting things using functions to represent data-types - and
probably will - but it's not a good general-purpose approach: there are plenty
of cases where we need objects and would really prefer not to have to build
our own. As for removing numbers: well, we were never seriously considering that.

So, back to the original purpose of Minima. It's not here to be as small as it
can possibly be - it's here to be as small as it can get away with being, whilst
still being reasonable to actually program in, so we can use it as a meaningful
base.

So whilst it's been interesting to see what's *technically* redundant, and why,
now is the time to make peace with our feature-set and start seeing what we can
do with this language.
