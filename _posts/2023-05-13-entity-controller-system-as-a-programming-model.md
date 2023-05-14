---
layout: post
title: Entity Component System as a programming model
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
Pandamonium is, perhaps unnecessarily, implemented using an Entity Component System architecture.

(Caveat: I have only read very surface-level things about Entity Component Systems, my approach has diverged over time, and I suspect it is abnormal and deficient in a bunch of ways. For now, I suspect those ways are ways I don't care about)

What does that mean, and why? Well, the best way to illustrate that is by example. Much of my game logic is implemented using functions like this:

```rust
fn translate(entities: &mut Entities, dt: &Duration) {
    entities.apply(|(Velocity(dx, dy), Position(x, y))| Position(x + (dx * dt.as_secs_f64()), y + (dy * dt.as_secs_f64())));
}
```

What's going on here? Very simply: we're applying a function to our entities, that takes a velocity and a position, and returns a new position. 

<!--more-->

OK, so, presumably, this moves all entities according to their current velocity and position?

Not exactly. See, not all entities _have_ a velocity and position. Many don't have a velocity, and some have neither. So what that does is: _for each entity which has a velocity and position_, update the position using the supplied function.

OK, so... what is an entity?

### Entities and Components

An entity is (conceptually at least) a collection of components. A component is a piece of data. For example - position and velocity are both components:

```rust
#[derive(Clone, Variable)]
pub struct Position(pub f64, pub f64);

#[derive(Clone, Variable)]
pub struct Velocity(pub f64, pub f64);
```

Note: components are typically pure, dumb, transparent data: no behaviour, just state. Any logic about how these components interact exists outside them, implemented independently.

Note also these components have identical implementations, and are distinguished purely by their type.

An entity may have any number of components, but only one of any given type. An entity can have a position, or not have a position, but it can't have _two_ positions. Here's how we define a spring, for example:

```rust
#[derive(Clone, Constant)]
struct Spring;

pub fn spawn_spring(x: f64, y: f64, entities: &mut Entities) {
    entities.spawn(entity()
        .with(Spring)
        .with(Position(x, y))
        .with(Interacts::Spring)
        .with(Mesh(ConvexMesh::new(vec![(0.3, 0.0), (0.7, 0.0), (0.7, 0.2), (0.3, 0.2)], vec![]).translate(x, y)))
        .with(Sprite::new(0, 8, 0.7))
    );
}
```

A spring has a position, a collision mesh, a sprite, some rules about interaction, and a marker type that basically exists just to say it's a spring. The `with()` method we use to add properties to an entity only cares that they're components, and components can be declared anywhere: the entity framework code doesn't know anything about `Spring`. 

So: that's an example of something which doesn't move, which wouldn't be affected by our `translate` method, because it doesn't have a velocity - in contrast to something like, say, the floating text element.

```rust
pub fn spawn_text(x: f64, y: f64, text: &str, entities: &mut Entities, events: &mut Events) {
    let text_id = entities.spawn(entity()
        .with(Position(x, y))
        .with(Text { text: text.to_string(), justification: align::CENTER | align::MIDDLE})
        .with(Velocity(0.0, 2.0))
    );
    events.schedule(Duration::from_millis(600), Destroy(text_id));
}
```

Ok, cool. But why take this approach?

### Data Models Don't Suit Games

In a traditional OO approach, I'd be defining the various different types of objects with, well, types. This gives me a few options:

I could define entirely different types for each entity, implementing common interfaces to describe their behaviour with methods like `render()`, `update()` and so on.

Or I could split entities into broad classifications - say, in a shoot-'em-up like Gradius, I might want `Player`, `Enemy`, `Bullet`, `Powerup`, `Particle` and `Wall` - with variation within those types achieved via parameterisation.

I have a tension between boilerplate and hierarchical abstraction here. Either the same code exists in multiple places, or I need an idea of how these types relate to each other, how they're classified into subgroups, in order to determine how to share code.

But my problem here is: the similarities between the types of entities I want for _this_ game (and, for that matter, many games) are _not_ hierarchical. There is no base set of properties or behaviours common to all entities, save possibly identity.

What I want is a compositional approach. At least, to state.

### What About Logic?

That's entities and components, but there's one last part to an ECS approach: systems. Components are bits of data, and entities are aggregations of components: so far, all we have is data. The logic, the behaviour: that lies in the systems. 

The OO approach to game logic would suggest state and behaviour should live together. That's an approach I could take: in addition to a list of properties I provide to any new entity, I could also provide it with a list of behaviours: functions which act over the appropriate subsets of properties.

That's one approach, but it's not the one I'm taking. Rather, I'm defining behaviour by a system of universal functions. If you have a sprite and a position, then you get drawn. If you have a velocity and a position, you move. And so on.

So, for example, this is a system:

```rust
fn translate(entities: &mut Entities, dt: &Duration) {
    entities.apply(|(Velocity(dx, dy), Position(x, y))| Position(x + (dx * dt.as_secs_f64()), y + (dy * dt.as_secs_f64())));
}
```

This approach has a number of benefits: it reduces boilerplate of passing the same common functions into many entities, it eliminates the risk of forgetting to attach an important behaviour. It models functions on the simulation that constitutes the game as a set of physical laws, which makes a lot of sense to me.

It also provides a lens to think about _interactions_ between entities. Our player character can collect coins. Where should that logic live? It's not a behaviour of the player character _or_ a coin, per se, it's about the _both_ of them.

If we're applying our logic from the outside, not attached to any individual entity, we can define functions over pairs of entities in exactly the same way as we define functions over individual entities.

This approach has some drawbacks, too! It becomes harder to determine _what_ logic is being applied to a given entity, as it's inferred rather than defined, and it requires some new approaches if we want to exclude a given entity from a particular behaviour. These seem like a more than reasonable tradeoff to me, in the situations I've encountered. Your mileage may well vary.

### Performance?

A lot of the conversation around entity component systems is about them being very high performance for games. This is not true of what I've built. At least, not currently.

I haven't designed this to maximise runtime performance: I'm building dinky little 8-bit style games. I've built it to maximise _developer_ performance, particularly at the trying-new-ideas stage. Adding new components or behaviours is very, very low boilerplate, meaning I can try out new ideas often in seconds, and the code is free of extraneous noise, meaning it's very clear to me exactly how all these various systems work.

That's not to say that there isn't room for increasing performance: there's a lot of low-hanging fruit in my implementation, which I haven't pursued because I'm already running fast enough for my needs. I'll touch on that when I dive into exactly how all of this works.

Equally, there are some decisions I've made which limit performance in pursuit of a nicer API. This isn't even a tradeoff, as far as I'm concerned, for as long as I'm already running at 60fps, which I imagine I will continue to do for some time.

### Magic

The bit that I find really cool, though, is exactly what's going on in this application of logic to entities:

```rust
fn translate(entities: &mut Entities, dt: &Duration) {
    entities.apply(|(Velocity(dx, dy), Position(x, y))| Position(x + (dx * dt.as_secs_f64()), y + (dy * dt.as_secs_f64())));
}
```

This is doing some powerful magic under the hood, leveraging both Rust's powerful static type inference _and_ its dynamic typing capabilities in concert, in a way that simply isn't possible in languages like Java or Python. I've also done similar things in Haskell, so this is by no means unique to Rust.

It's cool, but you don't need to understand the implementation to use it: it just provides a simple, intuitive API. Give me a function, and I'll apply to everything I can apply it to.

I'll get into how this all works in the next post.