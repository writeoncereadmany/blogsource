---
layout: post
title: Carpet-Oriented Programming
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the third in a series of posts about [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. You can find [the introductory post here](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly), and
a [critique of different ways to represent failure here](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java).

Before we look at railway-oriented programming with `Result`, it'll help if we
start with the similar, but simpler case of carpet-oriented programming with
`Optional`. And we'll do this by investigating the case of the King of France's
beard.

<!--more-->

### The King of Spain's Beard

So we want to know the colour of the King of Spain's beard, for reasons too
obvious to go into. Disregarding error handling, we might write something like
this:

```java
public String describeKingsBeard(Country country) {
  Person king = country.getMonarch();
  Beard beard = king.getBeard();
  Color beardColour = beard.getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```

The problems here are twofold:
 - The country may not have a monarch
 - If it does, the monarch may not have a beard
 - That said: if they do have a beard, it will have a describable colour

So we could represent this by returning null from the respective methods,
and then checking for it before proceeding:

```java
public String describeKingsBeard(Country country) {
  Person king = country.getMonarch();
  if(king == null) {
    return String.format("%s does not have a monarch", country);
  }
  Beard beard = king.getBeard();
  if(beard == null) {
    return String.format("%s does not have a beard", king);
  }
  Color beardColour = beard.getColour();
  return String.format("The king of %s has a %s beard",
                       country,
                       beardColour.describe());
}
```
