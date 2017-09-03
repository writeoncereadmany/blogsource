---
layout: post
title: Syntactic Overloading in Minima
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

This is the second in a series of posts on the [Minima language](https://github.com/writeoncereadmany/minimalang). [Here's the first](https://writeoncereadmany.github.io/2017/09/a-minima).

There are a few things I've made a very conscious decision to try to enforce
in the design of Minima.

These include, but are not limited to:
  * No nulls/uninitialised state
  * No inheritance
  * No reflection
  * No overloading

The first three are simple: I just don't introduce those features. There's no
way to define a variable without its initial value: the syntax doesn't support
it. There's no concept of classes, let alone subclasses. And there's no way
to introspect an object or function.

What happens if you try to access an undefined field of an object, you ask?
Not null, that's for damn sure. You get a type error. At runtime, yes. We'll
do something better about that later.

Overloading of functions is similarly not supported - any one given name
resolves to exactly one value - but I didn't just say no overloading of
functions. I'm also concerned about overloading of *syntax*.

<!--more-->

For example, in Java, parens `()` are used in two contexts: method invocation and
precedence of (eg arithmetic) sub-expressions. The period `.` is used in two
contexts: a separator for floating-point numerals, and field/method access on
objects. Angle brackets `<>` are used individually to delimit type arguments,
and also as the less-than and greater-than mathematical operators.

I don't want to do that. It makes code much simpler and clearer when a given
symbol can only mean one thing. There are four sorts of grouping: arguments,
groups, objects, and precedence - and a standard ASCII keyboard
has three sets of brackets: `{}`, `[]` and `()` (excluding `<>`, on the basis
we value `<` and `>` higher as mathematical operators).

This gives us two dilemmas. The first is what to use where; the second is we
have more use-cases than tools available.

In terms of what gets first pick of the cherry, there's a symbology which has
priority over any programming conventions - and that's maths. Regardless of in what
context we'll be using whatever language Minima develops into, we'll need to
support basic arithmetic. That means the basic set of operators: `+`, `-`, `*`,
`/`, `=`, `<`, `>`, and `()` for precedence. That's also how parentheses are
used generally (in English): to define subclauses, evaluated in their own right
and then incorporated into the larger context.

More than anything, that's what readers are used to believing parentheses are *for*.

That leaves arguments, groups and objects. Groups, or blocks, generally use
one of two syntaxes: `{}` in curly-brace languages, and significant whitespace
in languages like Python and Haskell. Objects and classes generally use one of
two syntaxes: `{}` in curly-brace languages, and significant whitespace in others.

This makes one decision easy: what to use for arguments. We don't have anything
competing for `[]`, so we can use that there. Generally, languages use `[]` for
indexing into arrays, but we don't have arrays or lists as a language-level
concept.

So let's get back to `{}` - who gets that, groups or objects? Fortunately, there's
a cool trick here that makes our problem go away. If we define a group as being
a sequence of expressions which are all evaluated, returning the value of the
last expression (which we did), then *a group of one expression is equivalent
to a parenthesised expression*.

That leaves `{}` free for objects.

We don't want to overload `.`, and there isn't really a sensible alternative for
numeric literals, so it's out for object field access. So we use `:` instead.

### Syntactic symmetry

Now, that means that technically speaking, we have two overloaded sets of symbols.
The `[]` square brackets can mean something is an *argument* list or a *parameter*
list, and the `:` operator can be used both to *define* a key-value pair in an
object and to *access* an object's field via the key.

In each of these cases, though, whilst they're distinct syntactic constructs,
they're symmetrical views on the same concept. Square brackets `[]` can be used to
define or invoke a function, but they always refer to the input to a function.
The colon `:` can be used to define or access a field, but it's always defining
how a given value relates to an object.

That's not an ambiguity. Quite the opposite: it reinforces the syntax.

### Point free programming

This shortage of bracket types would just go away, if we didn't need brackets
for function invocation - if we used the point-free style. Haskell doesn't need
them, so why should we?

Well, let's take this function as an example:

```
greet is [] => println["Hello, World!"]
```

In the point-free style, how would you invoke such a function? It'd just be

```
greet
```

And how would you reference such a function to, for example, pass it into
another function as a callback? It'd just be:

```
maybeDoSomething[greet]
```

But when we evaluate `greet` to pass it into `maybeDoSomething`, that's an
invocation, right? Or is it? *How should the language know?*

Herein lies the problem. The point free style is fine when there's no difference
between a function invocation and an uninvoked function, to be invoked later.
There's a name for that concept: *referential transparency*, and it's only true
of pure programming languages.

Haskell is pure: there *is no distinction* between a zero-arg function and its
result after invoking. Minima is, quite deliberately, not pure.

Whilst I believe purity is an important concept, I have other ideas about how
to deal with it, which will come up as we build atop Minima.

In a language which is not point-free, it's easy to differentiate between
an invocation of a zero-arg method, and an uninvoked zero-arg method: `greet[]`
is an invocation, and `greet` is a function.

Plus, the shortage of brackets isn't really a problem, not since we understood
how parenthesisation can be viewed as a special case of grouping.

### Maths!

One thing you can't do in Minima is this:

```
print[2 + 5]
```

That's because there's no syntactic support for mathematical operators. It's
not super complicated to add that - and indeed, that'll be one of the features
we add to Minima in the future. Never fear, though, because we can still do
maths. It's just not quite as readable:

```
print[2:plus[5]]
```

Numbers are objects, which means they can have fields - and fields can be
methods. Numbers support the following methods: `plus`, `minus`, `multiplyBy`,
`divideBy`, and `show` - which returns a String representation of the number.

They don't support any comparison operators right at the moment. We're probably
going to need those, but they open up some interesting questions for another
day.

### A note on equality and assignment

It's important not just to avoid overloading syntax, but also to avoid
overloading *expectations* on syntax.

I get particularly annoyed with the approach taken to the use of `=`. Many
languages use `=` for assignment, which means they end up using `==` (and
sometimes even `===` too!) for testing for equality.

One language which gets this right is Prolog, where testing for equality and
assignment are just different views on the same operation: unification. It's
reasonable to use one symbol for one concept! And that's what lies closest
to the meaning of the `=` symbol as used in mathematics: these two things are
conceptually equivalent.

My approach is to use `=` for testing for equality (although that's not
syntactically supported yet, it will be). For assignment, instead, I use `is`.
This is, like much of Minima, forward-looking: assignment uses `is`, so
*re*-assignment (not currently supported) can use `becomes`, because updating
a variable in-place is fundamentally different to creating a new variable and
deserves distinct syntax.

And that distinct syntax should require more typing, so people have an
opportunity to *really think about what they're doing* when they use it.
