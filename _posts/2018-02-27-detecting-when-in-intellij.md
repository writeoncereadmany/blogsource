---
layout: post
title: Detecting when you're in IntelliJ
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

How do you make your tests aware if you're running them from your IDE or not?
That's what I've been wrestling with, and there were some surprising results,
so I thought it would be worth sharing.

<!--more-->

But first of all, why on earth would you ever care?

When I joined the team at Unruly, we had a suite of acceptance tests for our
exchange, each of which called `main()` at the beginning of the test so we had
something to test against. That meant we could just invoke the test from within
IntelliJ, debug the exchange from a test, etc. Everything was nice and convenient.

Some things, however, were too convenient. As we were starting the exchange
programmatically, we could do things like inject test doubles, replace statics,
and generally fool around with the guts of the exchange. We weren't actually just
invoking `main()`, we were constructing a test exchange and starting that.
This meant that our acceptance tests weren't really acceptance tests - and that
isn't just a semantic argument.

On more than one occasion, we broke application startup. Because our tests didn't
actually *start* the exchange, we only discovered that when a botched deploy left
us without a service in production.

#### Test Against What You're Going To Deploy

So we changed things. We removed the various injections and dependencies, stubbing
out behaviour at the edges rather than shoving mocks into internals, and got to
the point where we could run the exchange and its tests in different processes.
That way, we were actually testing against the exchange we were deploying, instead
of a jumble of exchange components.

Then we codified that, by removing the ability of tests to start the exchange.
The only way to run the acceptance tests was to already have an exchange started
and ready to run against. Doing this with a single instance of the exchange for
the entire AT run (as opposed to a fresh one for each test class) also forced us
to clean up some accidental dependencies on initial state.

Not only was this more principled, giving us better, more meaningful coverage,
it was also faster. The relatively expensive startup was being done once, instead
of dozens of times (once per acceptance test class). The gain wasn't quite as
large as I'd hoped for, but it was noticeable.

Sounds like a pure win, right? Well, except for the experience in the IDE.

#### Frictionless Feedback is Important

In order to run tests in the IDE, you had to remember to start the exchange first.
If you changed code, you had to remember to restart it. In order to debug, you
had to juggle in your head which process to restart (the tests? or the exchange?),
and in order to build and deploy, you also had to remember to stop the exchange.
Even when you remembered, it was just *fiddlier*. A few extra clicks, a requirement
to use the mouse instead of the keyboard.

#### Robust or Frictionless? Why not both?

The fast-feedback loop of everyday development was worse. It was easy to under-estimate
the impact that had. Also, the additional robustness and performance of the build
script meant we didn't necessarily need it in the IDE.

So what if we ran the tests against an exchange in a different process in the
full deploy script, but when we're in the IDE we start up the exchange in the
same process?

That requires two things: making the tests toggle-able as to whether they start
the exchange or not, and passing the toggle in. Surprisingly, the hard part was
the latter.

#### -DstartExchange=true

The first idea was to pass in a system property when running ATs from Maven.
If the property is set, the tests are being invoked from a Maven build, so don't
start the exchange. Otherwise, do.

I was very surprised when that didn't work: the property was being set even when
running tests in IntelliJ. It turns out that IntelliJ looks at the Maven config,
and applies any command-line arguments to test targets when running tests.

Thanks, IntelliJ! That was some help I didn't need or want.

As a result, I can't distinguish from where the tests are being run via
arguments provided in the Maven script.

#### Run configurations

The second idea would be to pass in a system property when running the ATs from
*IntelliJ*, with custom run configurations. It's easy to edit configurations to
pass in an argument, and Maven is unaware of them. It's also easy to share and
check them in, so it's not something you need to think about when setting up a
dev environment.

Of course, we don't just use a pre-existing run configuration: sometimes we'll
run "all tests", but then sometimes we'll run "only this case which just failed",
or "only this case I just wrote". That's fine - you can edit a default configuration,
and then any new JUnit configuration will inherit that.

*But you can't share and check in a default configuration*.

Which means that you have ATs working in the IDE, *until they don't*, and it's
totally unclear as to what the difference is between this case running by itself
and as part of a suite.

#### Something totally horrible

The third idea was a terrible, horrible, no-good, very bad idea. What if I just
looked in the system properties to see if, y'know, *maybe* there's something there
that tells me this is being run from IntelliJ?

And there was. The `sun.java.command` property is set to
`com.intellij.rt.execution.junit.JUnitStarter <...various settings...>` when run
from IntelliJ. So that gives me my function:

```java
private static boolean isRunningInIntelliJ() {
  return System.getProperty("sun.java.command", "").contains("intellij");
}
```

Let me repeat: I know this is horrible. It's fragile - I have no reassurance that
this will continue to work in future versions of IntelliJ, and I'm certain it
won't work from Eclipse.

But sometimes, in the absence of a principled way of solving a problem, all you
have are hacks. After all: it works, and if the alternative is either a loss of
robustness or frictionlessness, then you're better off swallowing your pride and
embracing the hack.

But if anyone knows a nice, principled way of doing this, please: let me know.
