---
layout: post
title: Reflections on Equality
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

As always, it started with a bug. We'd been extending the capabilities
of one of our services, to allow filtering deals on a new concept. While
introducing that new concept, some classes had new fields added. One of those
classes implemented `equals()`, but the method wasn't updated to account for
the new field.

The first-order fix was easy: just re-generate the `equals()` method. Trying to
protect against this class of problem reoccurring, though, is a really
interesting question.

Not because it's difficult to come up with a broader solution, but because
so many solutions are available. And they're all terrible in different ways.

But first, let's talk about `equals()`, and understand our problem.

<!--more-->

### Why equals() is problematic in Java

Java isn't unique in having a really, really bad approach to equality, but
I don't think I can imagine a way to approach equality that's as thorny as Java's.

Firstly, `Object` implements `equals()`. That means *everything* implements
`equals()`: even things like `Function` which have no possible sensible approach.

Secondly, `equals()` *takes* an `Object`, which means everything can be compared
to everything else, even when it doesn't make sense to do so. That means a
well-behaved implementation of `equals` needs to do runtime type-checks and casts.

Thirdly, Java has subtyping, which means you need to consider not only how
`equals()` works for your class but *also for any extenders of your class*, and
anyone extending the class needs to be aware of what you've done.

Altogether, this means that there are a number of best practices when
implementing `equals()` that need to be taken into consideration.
*Effective Java* has eight pages on how to do this properly, and a further
six on also implementing `hashCode()`.

What this boils down to is: the vast majority of the time, Java developers
*don't write `equals()` methods*. They use standardised templates to do so,
except in the few custom cases where custom logic is required
(for example, implementing `equals()` on a `List` requires that other
implementations of `List` with the same contents are considered equal).

Compare that to, for example, Kotlin, which has a concept of data classes which
implement `equals()` implicitly. Or Scala, which has case classes which
implement `equals()` implicitly. Or Haskell, where you can use `deriving Eq` to,
well, derive an implementation of `==`, Haskell's equivalent.

Because that behaviour's built into the language, any time you change type
definitions in Kotlin, Scala, or Haskell, the implementation of `equals()`
changes alongside.

But in Java, that doesn't happen. If you add a field to a class and don't change
its `equals()` method, you have an incorrect `equals()` method, and the standard
language and tooling do nothing to help you.

### On being a responsible programmer

It may seem reasonable to say: well, that's one of the responsibilities of
the programmer. When they make a change, they should have the presence of mind
to ensure it doesn't break anything. So, add this to the list of things that
the programmer should have at the front of their mind whenever making a change.

That attitude simply doesn't scale. There are only so many things that can be
held in the front of the mind at once, and there are much more important things
to be worrying about.

The responsible programmer should ensure changes don't break anything. Being
responsible, they will recognise there are limits to how much they can rely
on the presence of their own mind - and instead automate the problem away.

### Automating the correctness of equals()

There are five broad categories of solution to the problem:

 * Static analysis
 * Dynamic analysis
 * Static generation
 * Dynamic generation
 * Rewrite it in Rust

Even these five categories fall into two broader groupings: analytic and
generative. Before going into the pros and cons of each category, though,
a brief overview of what it is and how it could be used to solve this problem.

### Static analysis

Static analysis involves the use of tooling to analyse code without actually
running it. In the Java world, this includes tools like Checkstyle, PMD,
Error-Prone, the Checker Framework and more. Many tools in this category are
referred to as *linters*, after `lint`, an early static analysis tool for C.

Most of these tools have an API that allows you to define your own rules. So we
could build a plugin which looks at classes which implements `equals()`, and
performs various checks on that implementation. For example, in order to protect
against the bug we encountered, we could check that every field declared is
referenced in the `equals()` method.

Then, as long as the static analysis tool is part of our build process, we'll
find that if we forget to update `equals()`, our build will fail at the static
analysis step.

### Dynamic analysis

Whereas static analysis analyses code without running it, dynamic analysis
analyses code by running it.

*Wait, that's... that's just tests right?*

Well, yes. But tests are often thought about in very narrow ways, and I'm talking
about an approach which doesn't really fit there, and there's a nice analog to
some important aspects of static analysis.

One thing that's nice about static analysis is we implement our check and it's
applied generally, to the whole codebase. We can do that at runtime too.

First we could use reflection to find everything which implements `equals()`.
For each type we found, instantiate it twice with the same parameters: these
should be equal. Then for each parameter, instantiate it twice with that
parameter unequal but each other parameter equal, and these objects should not be
equal. If any type fails these rules, then we need to go look at the implementation.

I refer to this as 'dynamic analysis' because, like static analysis, it's
applied generally over a codebase instead of applying only to a specific
implementation (like most automated tests do) - only it's done at runtime.
It's a different mentality to traditional unit/acceptance/property-based testing.

But unlike static analysis, it tests what the code *does*, not what the code *is*.
We can combine it with property-based testing approaches to make much richer
assertions about behaviour than we could with static analysis.

It's entirely possible to write a test like that. Making it scalable and robust
is an exercise left to the reader. But we don't need to go all the way: let's
say we just want to ensure `equals()` is updated when the fields are updated.

We could use reflection to find everything which implements `equals()`. For
each implementation, ensure it's annotated with a new annotation which includes
the `serialVersionUID` of the type when it was generated, and then check that
matches the current `serialVersionUID`. Whenever the fields change, so does
the `serialVersionUID` and the test requires the method be re-generated.

This wouldn't test that the `equals()` method is *correct*, just that it's based
on the current fields of the class. But it's easy to build, and it solves our
actual problem: how to keep the `equals()` method correct when changing fields.

### Static generation

There exist tools which can generate data classes from a specification, such as
an XML schema. This has an appeal when, for example, we're trying to code to an
external standard which is expressed as an XML schema: we can directly implement
the documented types.

Another thing we could consider is generating our data types in another JVM
language, such as Kotlin, Scala, or Haskell (using Frege). After all, that's
just treating building the other language in the pipeline as a generator of JVM
bytecode, and we've already referenced how those languages give us a sensible
implementation of `equals()` for free.

Taking such an approach would mean that any data types generated through
such steps would always have an up-to-date `equals()` method: any changes to the
data type would automatically be applied to the `equals()` implementation.

One thing worth noting is that these approaches do their generation as a
separate process to the Java compilation, and therefore have to occur before
compilation, in order to be referenced by the code. That means they can't refer
to our main codebase.

There are also tools like Lombok which allow us to include data types in our
main Java codebase without implementing `equals()`, and allowing the compiler
plugin to derive the implementation for us.

### Dynamic generation

Maybe we're just taking the wrong approach here. Instead of relying on our
implementation of `equals()` being correct at build time, we should find a way
of doing it correctly at runtime. Maybe we're better off reflecting over the
fields of the class and checking them for equality rather than relying on
anything as prescriptive as *code*.

Tools exist for this: for example, Apache's `EqualsBuilder` has a
`reflectiveEquals()` method, which looks at whatever the class looks like
at the time it's invoked. Not only is this guaranteed to take into account
the structure of the data class you're actually running, it's also concise,
reducing the amount of code the maintainer needs to consider.

### Rewrite it in Rust

If we're considering writing our data classes in another language, like
Kotlin, then it's a small step to write other kinds of classes in Kotlin. This
opens up the question of where we draw that line: maybe we're better off with
*everything* being in Kotlin, not just our data classes.

There are obvious costs to rewriting in another language, but at the same time,
there are costs to multiple languages in the same codebase. Moving comprehensively
to a language which better meets your requirements will result in something more
consistent, simpler, and therefore easier to maintain.

### The Problem With Best Practices

There's a fundamental difference here between the two overarching categories of
analysis (be it static or dynamic) and generation (be it static, dynamic, or
transglottal): *generation requires awareness*. You can build your data types
using Lombok, or with `reflectiveEquals()`, or in a separate library, and then
one day a new developer on the team builds a simple data type and either isn't
aware of the agreed approach or just overlooks it.

This is always a risk whenever adopting any approach, but bear in mind: our
problem here was it was too easy to overlook something that needed to be done.
If our solution is also easily overlookable, then all we've done is defer the
responsibility to know and remember things: and now, the responsibility we've
deferred it to is something local to our codebase, something a newcomer is
much less likely to anticipate.

We wanted a better solution so we didn't have to think about so many things:
well, now we've reduced the effort of maintaining data classes, but we've
increased the effort of writing data classes.

Whereas, if we'd gone with an analytic approach, we only need to decide how we
want equality to work across our codebase once, apply it, and then we *don't
need to know about it any more*, let alone think about it. Any time we violate
our requirements, our build process will tell us what to do.

### The Problem With Analysis

There are three main problems with the analytic approach.

Firstly, it's much harder and more complex. Building static analysis checks is
not straightforward, and requires a reasonably deep understanding of both the
tool's API and the Java AST. Building dynamic analysis checks requires a deep
understanding of the reflection API. *Maintaining* those tests puts a
significant burden on a typical team.

Secondly, these tests tend not to be exhaustive: they look for specific ways
the contract can be broken, rather than asserting they are correct. It's
entirely possible people find new ways to violate the contract that hadn't
been anticipated.

Thirdly, in addition to the risk of false negatives (breaking the contract in
ways that hadn't been anticipated), there's also the risk of false positives -
reporting a problem with a contract which doesn't actually apply in that
situation. There are approaches to ensuring that's not a blocker, but they
have consequences - for example, you can exempt given types from a given check,
but then you have no protection in the case of future maintenance of that type.

For something as general as validating `equals()`, even if it's expensive to
develop, *this only ever has to be developed once, and not necessarily by us*.
Often, a pre-existing plugin exists somewhere, and if not, then if we develop it,
others can benefit in turn from our labours. This helps mitigate the first point.

As gaps in our analysis arise, we can extend the implementation to cover those,
and thus mitigate the second and third points - but doing so well can be hard.

Whereas, if we'd gone with a generative approach, each step would be much
cheaper, and we can use different generators as needs must.

### The Problem With Rewriting It In Rust

If we move our program to one in which our problem does not exist, then we
have solved our problem. That doesn't mean this is a good idea.

There are three main problems with rewriting it in Rust (or any other language).

Firstly, it's incredibly expensive. In order to solve a maintenance problem on
a small subset of trivial methods, we're replacing the entire codebase.

Secondly, there is a serious risk of transliteration errors. It's very
difficult to have any confidence that the rewrite maintains the important
behaviours of the original. Good acceptance tests can help with this, but it
is unusual to have exhaustive acceptance tests.

Thirdly, just because our new language is better at this particular task, that
doesn't mean it's even at least as good as our old language in other areas.
It's entirely possible we're solving a small problem and introducing a much
larger one, be it one of library availability, performance, tooling quality,
or ability to hire.

### So what to do?

A perfect solution doesn't exist. Each category has its own characteristic
issues, and each solution within that category adds more. It's worth asking
whether the benefits of any of these solutions outweigh their costs - whether
just reminding the team to be mindful of updating `equals()` is, actually, the
best solution.

I would however argue that analytic approaches are woefully underused in
general. This isn't the best use-case for them (it's an atypically hard problem
to solve generally), but reducing the number of things people need to be
mindful of is incredibly powerful. Finding better ways to defer the need to
pay attention to a computer, and doing so in increasingly general ways, is
something everyone could benefit from being better at.
