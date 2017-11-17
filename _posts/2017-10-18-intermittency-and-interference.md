---
layout: post
title: Intermittency, Interference and Isolation
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

> We disabled the tests because they were intermittent.

I was somewhat alarmed to hear this.

To an extent, it was understandable - these particular tests were failing
really _quite a lot_, and they were preventing us from deploying some basic
maintenance updates. Also, they were doing things we hadn't been doing
before, so it was possible the approach was flawed - fixing them would require
some investigation.

But these tests were *important* - they were a brand new regression test suite,
a last line of sanity-checks against unexpected changes in our journal formats.
So putting them back was a high priority.

<!-- more -->

The tests were quite simple: we write journals of various events out, and these
files are then handed over to a pipeline which processes them for reporting
purposes. We want to make sure that journal format is consistent, and to be
aware of exactly what changes we're making when we're doing so intentionally.

So, our tests were quite simple. We take a snapshot of the journals, then we
perform some action, then we look at the journals again, filter anything out
we'd already seen, and compare what's left to what we expect to be left.

When they failed, we were seeing nothing in the actual output. It was as if the
events didn't happen. We had some theories - were we trying to read from the
logs before buffers had been flushed? Were we seeing journal rotation happening
between our action and our read operation? We couldn't reproduce any of these
cases.

The key was that these tests were failing *a lot* in the full build, but it was
difficult to work out what was going on because they were passing when we
debugged them. They were also passing when we just ran them in the IDE.

Those are not the characteristics of an intermittent test.

Those are the characteristics of an _interferent_ test.

Our tests each reused basically the exact same input, and then ran different
assertions on the outcome. Our journals contained timestamps, but only with
second granularity.

So, when we ran the full suite of tests, we'd run a test, add some lines to the
journal, sample that journal, run the same scenario again _generating the exact
same output_, remove lines which matched what we'd seen before (including what
had just been generated), and hey, no log lines for this action.

Our tests were interfering with each other.

The solution was quite simple - make sure the tests each generated different
output. Seed the input with a different characteristic piece of data, and then
the output from each test case will be distinct and identifiable.

Furthermore, if rather than _filtering out_ lines not associated with an
individual event, we can _select for_ them - that enables the possibility of
running such tests in parallel in the future.

### In summation

If your tests pass in isolation, but not en masse, they're interfering with
each other. Somewhere, you have a shared dependence on mutable state - and
for end-to-end tests, that could mean files, databases, other services, all the
sorts of mutable state applications exist to manage.

If your tests are interfering with each other, then you need to find some way
of isolating them - of ensuring the bits of state that this test case interacts
with are distinctly separable from all other state.

If your tests aren't interfering with each other, there's a good possibility
they will in the future. Any time you're generating persistent state in tests,
work out on what basis you want to isolate one test from another.

Ideally, isolate on something you can randomly generate at runtime, so that when
people copy-and-paste an existing test to do something new in the future, the
right sort of isolation just magically happens.
