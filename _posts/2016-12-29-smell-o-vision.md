---
layout: post
title: Smell-O-Vision
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---

Take a look at this code snippet - a Java puzzler from the classic book of the same name by Josh Bloch and Neal Grafter:

```java
public class StrungOut {
	public static void main(String[] args) {
        String s = new String("Hello World");
        System.out.println(s);
    }
}

class String {
	private final java.lang.String s;

	public String(java.lang.String s) {
		this.s = s;
	}

	public java.lang.String toString() {
		return s;
	}
}
```

The answer is: it does nothing, and if you try to run it as a main method, you'll get:

```
Exception in thread "main": java.lang.NoSuchMethodError: main
```

Why? Because a main method has to take an array of String, and ours takes an array of *String*, and...

Talking about code can often be imprecise. At times like that it's nice to show the actual code, and also show what I want to talk about in it. Like this:

```java
public class StrungOut {
	public static void main("!!pink!!"String"!!end!!"[] args) {
        "!!pink!!"String"!!end!!" s = new "!!pink!!"String"!!end!!"("Hello World");
        System.out.println(s);
    }
}

"!!pink!!"class String"!!end!!" {
	private final "!!blue!!"java.lang.String"!!end!!" s;

	public "!!pink!!"String"!!end!!"("!!blue!!"java.lang.String"!!end!!" s) {
		this.s = s;
	}

	public "!!blue!!"java.lang.String"!!end!!" toString() {
		return s;
	}
}
```

The problem is there are two String classes here: `java.lang.String` (in blue) and our own `String` class (in pink). `main()` requires a blue `String`, but it gets a pink `String`, so it's not a `main()` method. But I don't really care about the puzzler here: I want to talk about the highlighting.
<!--more-->

This highlighting of blocks of code is a useful device when talking about code. I call it "Smell-O-Vision", because it's a good way of showing code smells in context.

It's easy to do: just surround the formatted code with a `<span class=whatever>` with a style which changes the background colour. 

The issue here is that I want writing blogs to be lightweight, so I'm using Jekyll with posts written in markdown - which doesn't really support that.

#### Do It Yourself

The first thing I did was to simply wrap the bits I wanted highlighted in spans manually. I'd build the site, then go in and modify the generated HTML.

On the one hand, this was definitely the right place to start: at a very low investment, it allowed me to verify I got the output I wanted.

On the other hand, this was definitely not going to be viable for anything more than that verification: every time I rebuilt the page, whether it be for an edit of the post or even introducing a new post, all my formatting was lost, and I couldn't even be sure of all the places I wanted it originally.

I knew where I wanted to be: I wanted to apply the highlighting as part of the page build process. This seemed like a big step though, as I'd need to work out the following:

- How to mark up the blocks I wanted highlighting in the source markdown
- How to plug behaviour in to the Jekyll build process
- Where to plug that behaviour in to the Jekyll build process
- How to write Ruby

That's a lot of problems to solve all at once. So I didn't.

#### Out of Band Post-Processing

I wasn't going to start getting into the Jekyll pipeline at first, so I wrote a processor that I could just use myself. This is fine while my blog is a couple of pages: after each build, I can just run it manually. 

I could even write a wrapper script to run Jekyll and then my post-processing step. I didn't, because at that point I'm building parallel infrastructure - that's the point to learn how to plugin.

So I'm trying to find a way to automate the post-processing of HTML that I had previously been doing manually. The first step was to come up with some sort of way of marking up code blocks for highlighting, so I knew what to highlight and how.

My first attempts were to introduce some markup that was clearly not Java: for example, `$pink$` and `$end$` for the beginning and end of a range to be highlighted in pink. This would have worked a treat if I was highlighting preformatted text, like this:

```
 public static void main(String[] args) {
	 System.out.println("Cheeseburgers!");
 }
```

But I wasn't. I was highlighting *Java code*, specified as so:

```java
 public static void main(String[] args) {
 	 System.out.println("Cheeseburgers!");
 }
```
Which generates:

```java
public static void main(String[] args) {
	System.out.println("Cheeseburgers!");
}
```

That's all formatted, on the expectation that what I give it is Java. So what happens when I introduce some non-Java markup to that? For example:

```java
 public static void main(String[] args) {
 	 $pink$System.out.println$end$("Cheeseburgers!");
 }
```

The generated HTML for the print line looks something like:

```
<span class="n">$pink$System</span>
<span class="o">.</span>
<span class="na">out</span>
<span class="o">.</span>
<span class="na">println</span>
<span class="n">$end</span>
<span class="err">$</span>
<span class="o">(</span>
<span class="s">"Cheeseburgers!"</span>
<span class="o">);</span>
```

That's not going to play nicely with an automated post-processor. The start tag is part of a larger element, and the end tag is split between two elements. That's just this case: I don't know what I need to prepare for in the general case.

What we ideally want is our markup to be rendered by the syntax highlighter into a single element within its own span, in a consistent way.

The issue here is: that's dependent on how exactly the syntax highlighter works. I started working on the assumption it was a pure lexer, on the basis that parsing was probably overkill for syntax highlighting and is made more complex than usual as snippets are supported, meaning you don't know what the root element is.

So I picked the only thing I could think of which would consistently be a single output regardless of context, and yet contain arbitrary payloads: a `String`. To ensure that I don't accidentally post-process regular `Strings`, require an unusual formulation which I can consistently avoid in the code I want to publish. For example, `"!!pink!!"` to open a pink block and `"!!end!!"` to close it.

So I build the following post-processor (in Python, because I know it and it's good at this sort of job):

```python
import fileinput
import sys
import re

def span(match):
    arg = match.group(1)
    if arg == 'end':
        return '</span>'
    else:
        return '<span class="{}">'.format(arg)

for line in fileinput.input(inplace=True, backup='.bak'):
    print re.sub('<span class="s">"!!([^!]*)!!"</span>', span, line.rstrip())
```

That seemed to work pretty well for the first couple of blogposts I used it on. I wasn't encountering any rendering problems with it: it handled all the cases I threw at it. It was a hassle having to re-run the script on my output after each build, but a huge step forward from doing the job manually. 

That said, I knew it wasn't going to scale, so I had to bite the bullet and do the job properly.

#### Plugging In

The next step was to integrate this into the Jekyll pipeline, which meant it was time to turn this into a plugin. That meant, at a minimum, I needed to:

- learn enough Ruby to express what I want
- understand the Jekyll pipeline so I can put my plugin at an appropriate location
- understand the Jekyll API so I can interact with things correctly

By now I had a strong idea of how I wanted to model , but that was too big a step to try and cross in one go. My initial approach was to just get the existing logic and model into the pipeline.

Learning enough Ruby to replace some strings with others according to a regex wasn't hard. Adding a plugin to the build is trivial: just put a `*.rb` file in `_plugins` in the root. And there was an obvious place to plug it in to, as well: post-render on posts. 

So, after a little (well, a lot of) experimentation and reading around the API, I ended up with the following plugin:

```ruby 
def extract_smell(content)
  content.gsub(/<span class="s">"!!(?<smell>[^!]*)!!"<\/span>/) do |match|
    smell = $1
    if smell == 'end' then '</span>' else "<span class=#{smell}>" end
  end
end

Jekyll::Hooks.register :posts, :post_render do |post|
   post.output = extract_smell(post.output)
   post.data["excerpt"].output = extract_smell(post.data["excerpt"].output)
end
```

And this does what I need, so I can run a Jekyll server and update the posts as I go, and just have smell-o-vision built in to my processing pipeline. Job done, right?

#### Doing It Properly

The job is, most emphatically, *not* done at this point. It works, but that's all I can really say for it. It's not scalable in a number of directions: if I wanted to integrate with a different syntax highlighter, or a different language, or a different output format, then there's no principled way of doing that.

How to model it properly, and how to implement a properly modelled solution, though - that's a topic for another time. Hopefully, I'll be able follow this up soon.