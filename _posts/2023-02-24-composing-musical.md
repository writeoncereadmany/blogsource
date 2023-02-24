---
layout: post
title: Composing Music
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
Currently, I'm trying to implement music for the game. 

Well, I already _have_ music: I've implemented a simple 4-channel audio device, capable of playing sine, 
triangle, pulse, and noise waves, and I've got a variety of tunes already built into the game. This is 
one of the best ones:

![image tooltip here](/assets/mario-coin-score.jpg){:width="500" .centered}
<!--more-->

That's a short high B, followed by a sustained higher E. It's a classic ditty, instantly recognisable as
the sound made when you collect a coin in a Mario game. Most sound effects in the NES days were actually
simple tunes, and what I've implemented so far works just fine for that:

```rust
Tempo::new(2, 250).using(&BELL, 3).play(1.0, 0.25, B, 4).play(1.25, 1.0, E, 4).build()
```
(for reference: that's using a tempo of 250bpm with 2 beats in the bar, played using the bell "instrument"
on channel 3, playing semiquaver B in the 4th octave on the first beat of the bar, then a crotchet E in the
4th octave a quarter-beat later)

Which is fine, for when my tunes are two notes. I'm comfortable hard-coding that sort of thing. 
But I don't just want music as sound-effects, I want music as _music_, glorious polyphonic (where poly=3), 
frantic, fast-paced music, providing both a sense of urgency and also acting as a countdown so players 
are aware of how much of their ten precious seconds per screen remains.

But even something slow and simple, like, say, the bassline to Stand By Me, looks like this:
```rust
Tempo::new(4, 120).using(&BASS, 0)
    .bar(1).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(2).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, A, 1).play(4.5, 0.5, Gs, 0)
    .bar(3).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 1.0, E, 0)
    .bar(4).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 0.5, Fs, 0).play(4.5, 0.5, E, 0)
    .bar(5).play(1.0, 1.0, D, 0).play(2.5, 1.0, D, 0).play(4.0, 0.5, D, 0).play(4.5, 0.5, Fs, 0)
    .bar(6).play(1.0, 1.0, E, 0).play(2.5, 1.0, E, 0).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(7).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(8).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .build();
```
That's a whole lot of code, not easily readable or modifiable - and I intend to write much busier
music than this! 

I need to find a way to scale my ability to make music.

### Data?

The obvious concern here is: music isn't logic, it's data, so I shouldn't be defining it directly
in code. If instead I define some sort of data format for it, I can author it in that and just load
it into the game in the same way I load other assets like sprites and level layouts.

This would then allow me to either come up with a concise, effective format I can write directly, or
build a separate tool which allows me to write music via something more intuitive, like a musical staff
or a tracker, independent of the game code: play pieces independently, from whatever start point I wanted,
with immediate feedback on the effect. With a separate authoring tool, the file format doesn't need to be
human-readable or human-modifiable - I could use something like `serde` to delegate serialisation responsibility.

Or, I could leverage existing tools or data formats, and not have to build my own solution. I could import
music as a WAV or MP3, and play it as a single, long sound. 

These are the sorts of solutions I'd pursue if I was on a team of more than me, if delivery was my goal, and if
the problem I was trying to solve was "having music". But none of those are actually true. This isn't my day job.

I specifically want to use this janky, lo-fi "sound chip" simulacrum, so WAV / MP3 is out. I could potentially
interface with something like MIDI, but that's a much richer model than I have so I'd have to grapple with
domain mismatch impedance. And I want to take a small step from where I am: a diversion into building a whole
music editor is a bit much. The only small step from where I am is serialising to/from something I can edit by
hand.

That's the only small step in the direction of data, at least.

### ...Not data?

It's worth reflecting on what problem I'm trying to solve here. I don't want a way to author music, in general.
I'm not going to be using it to serialise Beethoven sonatas: I'm not making Jet Set Willy here. I want to capture
a very specific vibe of 8-bit game music, with short, repetitive loops of music, with a lot of self-similarity.

Maybe my approach shouldn't to be to move it out of code, but to make it easier to do big things in code, by
building it out of smaller parts.

Maybe the solution to my music problem is: composition. Y'know, like functions.

Let's take another look at Stand By Me:
```rust
Tempo::new(4, 120).using(&BASS, 0)
    "!!pink!!".bar(1).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    .bar(2).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, A, 1).play(4.5, 0.5, Gs, 0)
    .bar(3).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 1.0, E, 0)
    .bar(4).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 0.5, Fs, 0).play(4.5, 0.5, E, 0)
    .bar(5).play(1.0, 1.0, D, 0).play(2.5, 1.0, D, 0).play(4.0, 0.5, D, 0).play(4.5, 0.5, Fs, 0)
    .bar(6).play(1.0, 1.0, E, 0).play(2.5, 1.0, E, 0).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    "!!pink!!".bar(7).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    "!!pink!!".bar(8).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    .build();
```
The pink bars are identical.
```rust
Tempo::new(4, 120).using(&BASS, 0)
    "!!blue!!".bar(1).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    "!!blue!!".bar(2).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, A, 1).play(4.5, 0.5, Gs, 0)"!!end!!"
    .bar(3).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 1.0, E, 0)
    "!!blue!!".bar(4).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 0.5, Fs, 0).play(4.5, 0.5, E, 0)"!!end!!"
    "!!blue!!".bar(5).play(1.0, 1.0, D, 0).play(2.5, 1.0, D, 0).play(4.0, 0.5, D, 0).play(4.5, 0.5, Fs, 0)"!!end!!"
    "!!blue!!".bar(6).play(1.0, 1.0, E, 0).play(2.5, 1.0, E, 0).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    "!!blue!!".bar(7).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    "!!blue!!".bar(8).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)"!!end!!"
    .build();
```
The blue bars are all the same _shape_, and we can make _all_ the bars the same shape without really changing the feel:
```rust
Tempo::new(4, 120).using(&BASS, 0)
    .bar(1).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(2).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, A, 1).play(4.5, 0.5, Gs, 0)
    .bar(3).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 0.5, E, 0).play(4.5, 0.5, E, 0)
    .bar(4).play(1.0, 1.0, Fs, 0).play(2.5, 1.0, Fs, 0).play(4.0, 0.5, Fs, 0).play(4.5, 0.5, E, 0)
    .bar(5).play(1.0, 1.0, D, 0).play(2.5, 1.0, D, 0).play(4.0, 0.5, D, 0).play(4.5, 0.5, Fs, 0)
    .bar(6).play(1.0, 1.0, E, 0).play(2.5, 1.0, E, 0).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(7).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .bar(8).play(1.0, 1.0, A, 1).play(2.5, 1.0, A, 1).play(4.0, 0.5, E, 0).play(4.5, 0.5, Gs, 0)
    .build();
```
So we could, in principle, extract an idea of a parameterised phrase:
```rust
// r is root, r_o root octave, a is the first walk-up note, b is the second
fn bass_bar((r, r_o): (f32, i32), (a, a_o): (f32, i32), (b, b_o): (f32, i32)) 
        -> Vec<(f32, f32, f32, i32)> {
    vec![(1.0, 1.0, r, r_o), (2.5, 1.0, r, r_o), (4.0, 0.5, a, a_o), (4.5, 0.5, b, b_o)]
}
```
and then use that:
```
Tempo::new(4, 120).using(&BASS, 0)
    .bar(1).phrase(bass_bar((A, 1), (E, 0), (Gs, 0)))
    .bar(2).phrase(bass_bar((A, 1), (A, 1), (Gs, 0)))
    .bar(3).phrase(bass_bar((Fs, 0), (E, 0), (E, 0)))
    .bar(4).phrase(bass_bar((Fs, 0), (Fs, 0), (E, 0)))
    .bar(5).phrase(bass_bar((D, 0), (D, 0), (Fs, 0)))
    .bar(6).phrase(bass_bar((E, 0), (E, 0), (Gs, 0)))
    .bar(7).phrase(bass_bar((A, 1), (E, 0), (Gs, 0)))
    .bar(8).phrase(bass_bar((A, 1), (E, 0), (Gs, 0)))
    .build();
```
That lets me build bigger tunes out of smaller phrases, but more importantly: to think of music as a sequence
of variants of structured sub-parts. I'm not going to argue that's what music _is_, but it's a large part of
how I _think_ about music, particularly the style of music I want to angle for here.

Turning a four-note phrase into a function makes this a little more concise and clearer, but say I wanted instead
to do Street Spirit (Fade Out) by Radiohead - that has a repeating pattern of 16 semiquavers played throughout,
arpeggiating one of 3 chords: the _information_ there is much, much less dense than the _notes_ are. Being able to
reduce that pattern to a single invokable thing not only makes it much easier to scale across an entire piece,
but also makes _intent_ a bunch clearer too.

I think I may be happy with my music hard-coded into the game with this approach. Let's see where it takes me.