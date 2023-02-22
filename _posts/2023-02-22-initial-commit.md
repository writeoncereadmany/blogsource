---
layout: post
title: "Pandamonium: Initial Commit"
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
The phrase "Initial commit" covers a real multitude of sins. It's shorthand for "I've done too much stuff
already to describe it meaningfully, so... here's all of what I've done so far". It's an admission that
an important step has been left too late.

Now, I have - I think - exercised good commit habits on Pandamonium, my current hobby project. But I've 
done a bunch of (I think) cool things with it that I'd like to share, and now I'm in a position 
where that's a bit overwhelming - I'm in an "Initial commit" position on the blog.

So I'll start with a brief introduction, post in-the-moment as I solve interesting problems, and slowly
backfill the more interesting choices made so far.

Here's what I've got so far:

![image tooltip here](/assets/pandamonium_screenshot.png){:width="500" .centered}

<!--more-->
### What is Pandamonium? 
At work, I do more-or-less constant remote pair programming. One of the important habits of pair
programming is managing pace: taking small, regular breaks. At one point, I was doing a MarioKart cup
in those breaks, to help distract me and reset my thought process.

The end goal of this is to be my new pomodoro break game, played in bursts of no more than 5 minutes. You're
a panda, frantically chasing a high score.

On each screen, you get 10 seconds to get to the flag, picking up as many coins as possible on the way.
Miss the flag, and it's game over. Theintention is to have those screens procedurally generated - so it's 
not just dexterity, it's also assessing the situation and planning a route on the fly. 

Once it's built I'll put it in an arcade cabinet in my home office (also to be built), running on a Raspberry Pi.

### Constraints, Goals, and Opportunities
My constraints are simple: graphically, it's not exactly advanced, but I'm harkening back to a chunky
pixel-style of the NES era. I do, however, want it to run at a consistent 60fps: this game is extremely
fast and precise. That should not be difficult on the technology I'm using.

I also want to control this with a proper joystick: the proper tactile sensation is very much part of the experience.

I'm _not_ particularly interested in solving this the simplest possible way, as will become obvious quite
shortly. The simplest possible way would be to use something like Unity. Sometimes, when it's not part
of the day job, reinventing wheels is fun.

And of course: it's an opportunity to learn new things and stretch myself. Maybe a language I'm not familiar with?

### Rust
I've made some small steps towards building little games before in Haskell and Python. Early experiments showed
me that I couldn't reliably get 60fps in Pygame, even when not really doing anything, and in Haskell I couldn't
find any support for joystick bindings.

So I was quite pleased when a little dabbling showed I could easily satisfy both of those criteria in Rust using
sdl2 bindings. sdl2 is perfect for my needs: all the basic game functionality you need for a throwback 2D game in 
a very simple API, providing very little game engine functionality.

My experience with Rust was really shallow, but it's a language I always wanted to learn more about, and games - 
which largely boil down to a bunch of manipulation of mutable state - would be an excellent way to make me engage
with Rust's type system: borrow checker, mutability types and all.

I do love grappling with a good type system.

### State of Play
The game's very much in the feeling-out stage at the moment. I'm pretty comfortable with the controls, and
I've got a basic loop through a small number of stages. I'm getting to the point where most of the foundations
are present, albeit with some cleanup required.

Currently, I'm working on music: I've got multi-channel tunes working, but without an ergonomic way of writing 
anything of any length: that'll be my next post, most likely.

[If you want to check it out, it's hosted on my Github](https://github.com/writeoncereadmany/rust-game). I've
only tested it on the Raspberry Pi and my Macbook, but it should work on anything with SDL2 installed and with
a Rust toolchain.