---
layout: post
title: Gold Cards, Production Systems, Temptations and Expectations
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

At Unruly, we devote 20% of our time to personal development, via Gold Cards.
[Benji recently made a good post about what they are and why we do them](http://benjiweber.co.uk/blog/2018/01/29/gold-cards/). Generally, I spend
much of my Gold Card time exploring new ideas - getting deeper into functional
programming languages, experimenting with porting those ideas into something
usable in our tech stack, and so on.

Sometimes, though, I see something about our codebase and think: "I could fix that".
And sometimes it turns out: yes, I can make some significant improvements in
just a day! There's just one problem: we're all about collaboration, and
"fixing" stuff unilaterally is antithetical to that philosophy.

<!--more-->

So. I've spiked a change. What happens next?

#### The First Time I Spiked A Refactor

We had all sorts of convoluted code in our GraphQL layer in our Java app. See,
the thing about GraphQL is: it's nice and easy to handle in Javascript, but the
Java support is much thinner on the ground, less developed, and Java as a
language just doesn't mesh with GraphQL as well as JS does. So it turned out we
needed quite a lot of boilerplate, and it turned out that in this fairly
tortuous code, we had (IMO) drawn the boundaries at the wrong place.

If we just separated *this* from *that*, like *just so*, we'd be dealing with fewer
concerns at any one point, and we could unit test some logic that was previously
enmeshed with this complex library and difficult to access cleanly.

So I did that, and got all the tests working, wrote some new unit tests to
demonstrate how we could, and popped it on a branch. (Side note: the only reason
I can see that branches are ever a good idea is to persist and share spikes.
Branches are fine as long as you never merge them).

I was pleased with my results. So, I presented my findings to the team. I was
less pleased with the response I got.

One person expressed doubt the approach would work in certain cases. Another was
concerned they didn't know how to get from A to B. Most frustratingly, someone
else said they wouldn't be comfortable merging work without pairing on it (which
is fair, that's our rule), but couldn't see prioritising pairing on it over other
dev tasks.

That last point was particularly frustrating. I'd put time into making something
better, and whilst there were some minor reservations, nobody disagreed that it
was better. And yet, there wasn't a path to actually *doing* it.

This was, of course, completely unreasonable. On my part.

I knew our practices and principles, and yet I went off on my own and did
something big in a way which didn't permit it to proceed. Then other people came
and said: okay, that seems nice, but you're way closer to it than us so we're
not sure about the subtleties. It didn't feel like that at the time, but that's
because I was too close to it.

I hadn't truly embraced it as a spike. I'd gotten too attached to it.

{% twitter https://twitter.com/GeePawHill/status/965073132569726977 %}

So what are the lessons to learn from this? Well, I can tell you about the time
I learned the *wrong* lessons:

#### The Time I Shouldn't Have Gotten Away With It

The second big change was something we'd all been moaning about for a while:
dependency injection. Working out what was going on with Guice, HK2, and the
bridge which connected two different dependency injection frameworks together(!!!)
was difficult to debug and made it difficult to work out where things came from.

I had some experience rolling back from DI frameworks to plain old Java from my
previous workplace, so I decided to find out how far I could get in a day. Turns
out I could get it all done, and have some reasonably-factored top-level wiring
classes to boot.

So I popped it on a branch, and presented it to the team. Everyone was pleased
with the result. The question then was: what next? And this is when I was
tempted by the dark side.

This took me a day, I argued. But it's all mechanical refactoring, so it would
take a pair longer.

What I didn't realise - or didn't admit to myself - was that a pair taking longer
was a feature, not a bug. I got it done in a day because I decided on my approach
and then applied it, consistently, robotically, without thinking - and sometimes
a little bit of thinking is actually a good thing when developing software.

It's all mechanical refactors around wiring, I argued. If anything were wired
incorrectly, it would show up in the integration/acceptance tests. All parts are
present and correct.

There's no such thing as a purely mechanical refactor. Especially as things get
larger, there are little decisions and analyses constantly being made, which
once done, are forgotten, and not presented back to the team.

One argument which I don't recall being made, but really should have been, was
that I'd just applied a process for removing a DI framework and *hadn't shared
those techniques with anyone*, meaning that a lot of my power-refactoring tools
remained firmly encapsulated in my head instead of distributed across the team.
I'd just done work that the rest of the team would find it difficult to replicate.

But everyone liked the result. A lot. So it was a question then of: well, how
do we get the code to look like this? Plus, I was still sore from the last time
I'd spent time on making the code better and then it didn't happen. It wasn't
about getting *my code* in, it was about *here's an improvement we all want, how
can we make it happen?* So I argued that whilst it was quite *big*, it was
*simple*, and we could get away with a code review and a merge.

And the team agreed.

{% twitter https://twitter.com/GeePawHill/status/965073132569726977 %}

Of course, there was a bug. A minor oversight: all of the strings which were
DI'd in were from properties files. All, that is, apart from one: the hostname.

The tests were fine: nothing blew up because it was just a string being concatenated
with other strings, nothing was logically dependent on it... until it hit our
reporting system, which is outside the scope of our application-level testing. We
weren't testing against those strings, because the expectations would have to
change depending on what machine we were running on.

Of course, the hostname is never validly "null". The tests couldn't catch that, though.

It was a quick fix. We reverted first, of course, but then fixed and re-applied
the change, and we've been better off for making it ever since. On the whole,
it was a good change.

But *how* we deployed that change was a mistake. We should have re-implemented
as a pair. Not because of the bug - there will always be bugs, and it's
results-oriented to focus on details like that. No, we should have re-implemented
as a pair because *that's how we do things*, and it's bad practice to break
rules for expediency.

By not pairing, we lost the opportunity to share the techniques used to
incrementally untangle DI. By not pairing, we lost the opportunity to consider
alternate approaches to the problem. And importantly, by not pairing, we
established - if just a little - that not pairing is OK.

It didn't take much hindsight for me to regret how that case was handled.

#### The Time I Made An Unmergeable Change

The next big change I wanted to try out was a fairly substantial refactor of
the internal logic of one of our systems. It seemed to me that we had a fairly
straightforward functional pipeline - *this* takes an A and spits out a B, then
*that* takes a B and spits out a C then eventually we get a `Response`.

This was not well reflected in the code. So I started fiddling about, seeing if
I could rearrange it to actually look like that. Unlike the wiring changes, though,
this wasn't rearranging the edges of the codebase - this was getting stuck in
right in the middle, making signature changes to key classes.

This led to me spending a lot of my time keeping the unit tests buildable.
Not passing - just compiling. Keeping them passing was taking substantially
longer, and distracting me from my task.

And yes, when your unit tests make refactoring slow, that's a sign that your
units probably aren't actually units. We already knew we had that problem: that's
one of the problems this refactor was hoping to help us with.

So, in order to validate a change in the large, I temporarily unmarked the unit
tests as a source folder in my IDE. Acceptance tests passing? Then I'm probably
on a reasonable track. Cool, time for lunch.

Whilst I was taking some time for lunch, I realised. *Why do the unit tests need
to pass?* I mean, obviously, I can't *deploy* with the unit tests disabled. But
to reiterate:

{% twitter https://twitter.com/GeePawHill/status/965073132569726977 %}

I don't *want* to deploy this. This is a *proof-of-concept*. The whole reason
why I got emotionally invested in the previous two pieces of work was I set out
to do research, but came back with what I considered finished work.

I can avoid that trap by doing this in such a way nobody could ever mistake it
for finished work.

Or to put it another way: letting the unit tests become unbuildable is a
*feature I can leverage*, to temper my own expectations, to make sure I don't
hit that seductive call of "this is so awesome, we should just push this".

And, by adopting that shortcut as principle, I finally embraced what I was
doing as a spike.

After all, spiking's all I *can* do by myself.
