---
layout: post
title: Doing stuff in Minima
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

This is the fourth in a series of posts on the [Minima language](https://github.com/writeoncereadmany/minimalang). [Here's the first](https://writeoncereadmany.github.io/2017/09/a-minima),
[here's the second](https://writeoncereadmany.github.io/2017/09/b-overloading-in-minima), and [here's the third](https://writeoncereadmany.github.io/2017/09/c-how-minimal-is-minima).

So far I've provided little more than explanations of syntax. So, let's have
a look at how to approach some actual problems in Minima. When I say actual
problems, I mean whiteboard screening questions: reversing a list and Fizzbuzz.

<!--more-->

### Reversing a list

Reversing a list isn't usually a particularly difficult problem, but that's in
languages which give you a little more to start with. Before we can reverse a
list, we first need a list: something Minima doesn't give us.

So what's a list? It's an ordered collection of elements. If you've got access
to pointers (or your standard library implementers do, which is basically true
of anything which runs on computers), you may choose to implement a list as an
array or vector. But we don't have access to pointers in Minima, and we don't
want to introduce new builtins.

What about a linked list, then? A linked list is nice and simple: it's either
a `node`, containing an element and a tail (the rest of the linked list), or it's
the empty list, `nil`. So we could implement it like so:
```
node is [head, tail] => {
  head: head,
  tail: tail
}

nil is {}
```
And then create a list as follows:
```
list is node[1, node[2, node[3, node[4, nil]]]]
```
We *could* do that, but we're going to hit a problem: when we iterate over this
list, how do we know when we reach the end? How do we detect we've hit `nil`?
We could implement some sort of `equals` method, but that requires a bunch of
other constructs like a boolean type and an if statement and that all sounds
terribly heavyweight just to reverse a string (although, to be fair, I suspect
they would be constructs we could easily reuse in other situations).

But we don't just have objects at our disposal to represent data: we saw how
we could represent data as functions in the last post. This approach becomes
particularly powerful when we want to represent data with multiple shapes, like
a list. For example:
```
node is [head, tail] => [onItem, onEmpty] => onItem[head, tail]
nil is [onItem, onEmpty] => onEmpty[]

numbers is node[1, node[2, node[3, node[4, nil]]]]
```
Here, a list is a function which takes two functions: the first one is invoked
if there are any elements, and the second is invoked if it's empty. So, for
example, we can implement some very simple functions:
```
isEmpty is [list] => list[
  [h, t] => "nonempty",
  [] => "empty"
]

head is [list, default] => list[
  [h, t] => h,
  [] => default
]
```
So far, so good. Before we reverse this list, it would be good to be able to
see what's in the list - let's find a way of printing it. Hmm...
```
showList is [list] => (
  contents is list[
    [h, t] => h:show[]:concat[???],
    [] => ""
  ],
  "list[":concat[contents]:concat["]"]
)
```
All this skeleton so far is fairly straightforward. We wrap the contents in
"list[]", and the contents are empty if the list is empty, and the contents
start with the head if it's non-empty. If it's non-empty, we then want to recurse
on the tail, so maybe something like:
```
showList is [list] => (
  content is [l] => l[
    [h, t] => head:show[]:concat[", "]:concat[content[t]],
    [] => ""
  ],
  "list[":concat[content[list]]:concat["]"]
)
```
And this would work - with a trailing comma, but whatever - if it weren't for
one thing. We can't recurse like this, because `content` isn't a named function.
The function we assign to `content` only has access to variables which exist at
the time we define it - but the *variable* `content` doesn't exist until we
assign the function to it, which is necessarily after defining it. As `content`
isn't in scope within its body, we can't call it.

Fortunately, we don't need named functions for recursion: there are constructs
which do it for us. In this case, we need the y-combinator, which in Minima looks
a little like this:
```
showList is [list] => (
  content is [l, cont] => l[
    [h, t] => h:show[]:concat[", "]:concat[cont[t, cont]],
    [] => ""
  ],
  "list[":concat[content[list, content]]:concat["]"]
)
```
Rather than expecting the function to recurse on to be available in the body,
we pass it in as an argument in addition to the other arguments. Then, when
you need to recurse, you just call the passed-in argument and keep passing the
function down for the next invocation.

Let's give the whole program a try:

```
node is [head, tail] => [onItem, onEmpty] => onItem[head, tail]
nil is [onItem, onEmpty] => onEmpty[]

numbers is node[1, node[2, node[3, node[4, nil]]]]

showList is [list] => (
  content is [l, cont] => l[
    [h, t] => h:show[]:concat[", "]:concat[cont[t, cont]],
    [] => ""
  ],
  "list[":concat[content[list, content]]:concat["]"]
)

print[showList[numbers]]
```
```
list[1.0, 2.0, 3.0, 4.0, ]
>
```

Okay! We're making progress! Now, let's reverse a list. Our approach is simple:
we start off with an empty list, and as we iterate along the list, we put each
element on the front of our list, and when we reach the end, we return what
we've built. Seems simple enough:
```
reverse is [list] => (
  inner is [l, acc, cont] => l[
    [h, t] => cont[t, node[h, acc], cont],
    [] => acc
  ],
  inner[list, nil, inner]
)

print[showList[reverse[numbers]]]
```
```
list[4.0, 3.0, 2.0, 1.0, ]
>
```

Success! Some observations:
  * Interacting with function-data lists feels very similar to pattern matching
  * Implementing recursion is a pain in the neck
  * It's interesting that we don't *need* explicit support for recursion
  * Lists feel like something we should have better support for

One other thing: it could be stated here that when we're building recursive
functions like this, we can build them one of two ways:
```
obviousReverse is [list] => (
  inner is [l, acc, cont] => l[
    [h, t] => cont[t, node[h, acc], cont],
    [] => acc
  ],
  inner[list, nil, inner]
)

efficientReverse is (
  inner is [l, acc, cont] => l[
    [h, t] => cont[t, node[h, acc], cont],
    [] => acc
  ],
  [list] => inner[list, nil, inner]
)
```
The difference here is that `efficientReverse` only creates the inner function
once, whereas `obviousReverse` creates it on each invocation. A few quick
thoughts on performance optimisations like this:
  * do not optimise Minima code for performance
  * the more efficient version of the code is about as readable as the obvious
  version, so there's no real downside to using that if you prefer it
  * *do not optimise Minima code for performance*
  * If performance is, or might be, an issue: don't use Minima

Okay, that's enough of that. Next up: Fizzbuzz.

### Fizzbuzz

For anyone who isn't familiar with it, Fizzbuzz is a number game in which you
count upwards from 1, only if a number is divisible by 3 you replace it with
"Fizz", if it's divisible by 5 you replace it with "Buzz", and if both, you
replace it with "FizzBuzz". So, for example, playing it up to 20 would yield:
```
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
16
17
Fizz
19
Buzz
```
Not super interesting, but it's a good way of testing basic programming ability:
functions, conditionals, loops and so on.

Let's start off simple: just print out the numbers 1 to 20.
```
fizzbuzz is (
  inner is [current, max, cont] => (
    print[current]
    cont[current:plus[1], max, cont]
  ),
  [current, max] => inner[current, max, inner]  
)

fizzbuzz[1, 20]
```
Well, obviously, this doesn't just print the numbers 1 to 20 - it keeps printing
numbers forever (or until we run out of stack), as we don't have a condition to
stop it looping.

We could be more specific: in Minima, we don't have conditions. And now we need
them. We're going to try to avoid introducing a builtin `boolean` type, so let's
go back to functions-as-data.
```
true is [ifTrue, ifFalse] => ifTrue[]
false is [ifTrue, ifFalse] => ifFalse[]

print[true[[] => "yay", [] => "nay"]]
print[false[[] => "yarp", [] => "narp"]]
```
```
yay
narp
>
```
Depending on what we like syntactically, we could opt do something like this:
```
if[cond, actions] => cond[actions:then[], actions:else[]]

statement is if[true, {
  then: [] => "yay",
  else: [] => "nay"
}]

print[statement]
```
There's a lot we could do. The long and short of this is that we can introduce
decision-making functions which can sensibly be described as `true` or `false`
without introducing any new fundamental concepts.

That doesn't mean we can implement `FizzBuzz` without adding to the built-ins,
though - although we don't need to add much. To print the numbers 1-20, we need
a new method on numbers: `lessThan`. That allows us to do this:
```
fizzbuzz is (
  inner is [current, max, cont] => (
    print[current]
    current:lessThan[max][
      [] => cont[current:plus[1], max, cont],
      [] => SUCCESS
    ]
  ),
  [current, max] => inner[current, max, inner]  
)

fizzbuzz[1, 20]
```
Note this doesn't require we add `true` and `false` to the Prelude - we can
just return anonymous functions from `lessThan`. But at that point, not adding
them to the Prelude just seems churlish.

And this works:
```
1.0
2.0
3.0
4.0
..
20.0
>
```

We just need one other thing here: to check whether a number is divisible by 3
or 5. We could implement a `modulo` or `%` operator, but then we'd also need
`equals`, so for now, let's just be incredibly direct and implement a
`dividesBy` method on numbers. That lets us write this:

```
fizzbuzz is (
  inner is [current, max, cont] => (
    current:divisibleBy[3][
      [] => print["fizz"],
      [] => print[current]
    ],
    current:lessThan[max][
      [] => cont[current:plus[1], max, cont],
      [] => SUCCESS
    ]
  ),
  [current, max] => inner[current, max, inner]
)

fizzbuzz[1, 20]
```
Which yields:
```
1.0
2.0
fizz
4.0
5.0
fizz
7.0
..
20.0
>
```

And then we can extend it to include buzz as well:
```
fizzbuzz is (
  inner is [current, max, cont] => (
    fizzy is current:divisibleBy[3],
    buzzy is current:divisibleBy[5],
    fizzy[
      [] => buzzy[
        [] => print["fizzbuzz"],
        [] => print["fizz"]
      ],
      [] => buzzy[
        [] => print["buzz"],
        [] => print[current]
      ]
    ],
    current:lessThan[max][
      [] => cont[current:plus[1], max, cont],
      [] => SUCCESS
    ]
  ),
  [current, max] => inner[current, max, inner]
)

fizzbuzz[1, 20]
```
Now, there's more we could do here. This isn't a particularly elegant way to
build a decision tree - but it is *a* way to build a decision tree, and we've
avoided having to add too much.

So: what? I've solved two incredibly simple problems in a way which, at first
glance, seems vastly more complicated than <insert your favourite language here>.
But the point is that these things are *possible*, with some basic patterns,
without language features required to do such fundamental things as recursion
and decision-making.

Clearly Minima isn't a language we want to use every day to solve these problems.
But similarly clearly, it's capable as a foundation.

And hopefully, this has provided an interesting perspective on what the concepts
of recursion and decision actually *are*.
