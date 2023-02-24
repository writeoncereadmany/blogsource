---
layout: post
title: It's Just Intonation
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
Following on from my last post, I was starting to get annoyed by the way I'd chosen to represent note frequencies. For example:

```rust
Tempo::new(2, 250).using(&BELL, 3).play(1.0, 0.25, B, 4).play(1.25, 1.0, E, 4).build()
```
I'd been represeting B4 as two separate values: a frequency and an octave. That permitted me to just define each 
letter-note once, and rely on math rather than specification to make everything work. However, when I start to get to
solutions like this:

```rust
// r is root, r_o root octave, a is the first walk-up note, b is the second
fn bass_bar((r, r_o): (f32, i32), (a, a_o): (f32, i32), (b, b_o): (f32, i32)) 
        -> Vec<(f32, f32, f32, i32)> {
    vec![(1.0, 1.0, r, r_o), (2.5, 1.0, r, r_o), (4.0, 0.5, a, a_o), (4.5, 0.5, b, b_o)]
}
```
```
Tempo::new(4, 120).using(&BASS, 0)
    .bar(1).phrase(bass_bar((A, 1), (E, 0), (Gs, 0)))
    .bar(2).phrase(bass_bar((A, 1), (A, 1), (Gs, 0)))
    .build();
```
Having to provide tuples and destruct them to get their constituent parts... I'm now thinking I want to change my approach.
I don't particularly mind having 88 constants - maybe even upwards of that! - if they're simply defined and simple to use:
the relative importance of the use-cases vs the declaration-site has changed.
<!--more-->

### Scaling Musical Scales
So, before I start changing all my notes from ignoring the octave to including it in the name, using 
[scientific pitch notation](https://en.wikipedia.org/wiki/Scientific_pitch_notation) (which it turns out I'd gotten wrong 
first time round: each octave starts at C, not A)... how do my notes look at the moment?
```rust
pub const A: f32 = 220.0;
pub const As: f32 = 233.082;
pub const Bb: f32 = As;
pub const B: f32 = 246.942;
pub const C: f32 = 261.626;
...
```
Okay, so I'm defining a bunch of specific, hard-coded values. That's... fine, I guess? But I'd rather show my working.
A# is 2^(1/12) of the frequency of A, so why don't I just say that explicitly?
```rust
pub const As: f32 = A * 2.0_f32.powf(1.0/12.0);
```
```
error[E0015]: cannot call non-const fn `std::f32::<impl f32>::powf` in constants
 --> src/audio/notes.rs:4:33
  |
4 | pub const As: f32 = A * 2.0_f32.powf(1.0/12.0);
  |                                 ^^^^^^^^^^^^^^
  |
  = note: calls in constants are limited to constant functions, tuple structs and tuple variants
```
Oh. I probably tried last time and got the same error. It's slightly annoying that `powf` _isn't_ a constant function,
it feels like it _should_ be? But I'm not about to go implementing my own version of `powf` just to clean up my list of
notes. 

So, I guess I could calculate each of the note offsets, or look them up, and use that in how I define notes going forward.
I mean, I could use these values I've already calculated, but I'd ideally like to switch from this approach to something more
like:
```rust
// reference tone
const Octave4: f32 = 440.0

pub const A: f32 = 1.0;
pub const As: f32 = 2.0_f32.powf(1.0/12.0); // yes I know I can't but that's what I'd ideally intend
...

pub const A4: f32 = Octave4 * A;
pub const As4: f32 = Octave4 * As;
...
```
i.e., have standard offsets for each letter-note and apply those to the octave for each absolute note. So: pre-calculate
(or look up) and bake in?

Well, now I'm thinking about it, maybe that's _not_ what I want.

### I'm Not Sure I Have The Right Temperament For This

All that 2^(1/12) stuff is how musical notes' frequencies relate to each other... in 12-tone equal temperament, 12TET for short. There's actually more than one way to tune a cat, and over time musicians have generally converged on 12TET as a versatile 
compromise (largely due to the influence of the piano), which is always _slightly_ out of tune but not enough to really 
notice, as opposed to other systems of intonation which can be _perfectly_ in tune for most intervals but badly _out_ of 
tune for others.

If this sounds interesting, I recommend [How Equal Temperament Ruined Harmony (And Why You Should Care)](https://www.amazon.co.uk/Equal-Temperament-Ruined-Harmony-Should/dp/0393334201) - it's a fascinating read, especially if you like both music and math.

![image tooltip here](/assets/equal-temperament.jpg){:width="300" .centered}

It would probably be a good idea to use 12TET if I wanted a general music system, allowing me to write arbitrary music in an
arbitrary key. But I'm not _intending_ to write arbitrary music in an arbitrary key, I'm going to write a very small number of
pieces and know what key they'll be in, in advance. So... I could instead use [just intonation](https://en.wikipedia.org/wiki/Just_intonation), and the intervals will be that bit purer, sound that bit better... and also, the maths will be easier.

```rust
pub const C: f32 = 1.0;
// under 12TET: messy, difficult to understand, doesn't even compile!
pub const G_12TET: f32 = 2.0_f32.powf(7.0/12.0);
// under just intonation: a perfect pythagorean ratio!
pub const G_JUST: f32 = 3.0/2.0;
```

I'm not trying to justify changing the way music works just to make the maths easier and work around a compiler limitation.

But if I hadn't been thinking about how to make the maths easier and work around a compiler limitation, this wouldn't have
occurred to me, which _at the very least_ will be an interesting musical experiment.

Ok, time for some dinner, then I'll flesh out 88 constants...