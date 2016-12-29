---
layout: post
title: "Optional: other options"
author: Tom Johnson
published: false
excerpt_separator: <!--more-->
---
What are `Optional`s for?

Through my last post, I was talking about how they exist to represent the possibility of absence, and to force users to cater for it. That's a very limited way of looking at the problem, viewed through a lens of talking about `Optional`s alone. They're actually a solution to a broader problem, and they're not very good at solving that problem.

Let's take an example. Let's say that we want to find out what grade someone's eldest child got in history last year. Simple enough:

```java
public Grade eldestChildHistoryGrade(Person person) {
	return person
	          .getEldestChild()
	          .getReportCard(lastYear)
	          .getGrade(Subjects.HISTORY);
}
```

The thing is - it's possible there isn't a sensible answer to this question. The person may not have children. They may, but they could be pre-school or have finished education, and thus not have a grade for last year. And finally, they may have been in education but not studying history that year.

In other words, it's possible that last year's history grade for that person's eldest child doesn't exist. That sounds like a case for `Optional`:

```java
public Optional<Grade> eldestChildHistoryGrade(Person person) {
	return person
	          .getEldestChild()
	          .flatMap(child -> child.getReportCard(lastYear))
	          .flatMap(card -> card.getGrade(Subjects.HISTORY));
}
```

This allows us to represent the possibility of nonexistence for each of our operations, and compose them into a single operation.