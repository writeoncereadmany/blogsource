---
layout: post
title: What About The Rest Of The World?
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
This is the seventh in a series of posts introducing [co.unruly.control](https://github.com/unruly/control),
a functional control library for Java. Previous parts:
 - [Most code fails badly](https://writeoncereadmany.github.io/2017/11/most-code-fails-badly)
 - [How to fail in Java](https://writeoncereadmany.github.io/2017/11/how-to-fail-in-java)
 - [Carpet-oriented programming](https://writeoncereadmany.github.io/2017/11/carpet-oriented-programming)
 - [The difference between functions and methods](https://writeoncereadmany.github.io/2018/02/a-the-difference-between-functions-and-methods)
 - [The Applicable Pattern](https://writeoncereadmany.github.io/2018/02/b-pipe-dreams-or-the-applicable-pattern)
 - [Railway-Oriented Programming](https://writeoncereadmany.github.io/2018/02/c-railway-oriented-programming)

I should apologise. In the last post, I cheated slightly.

<!--more-->

We started with this:

```java
public Response updateEmail(String requestBody) throws IOException {
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    String newEmail = canonicalise(request.newEmail);
    account.setEmail(newEmail);
    accountRepository.update(account);
    return ok("E-mail address updated");
}
```
Then we noted that we weren't handling any errors, so we added in handling:

```java
public Response updateEmail(String requestBody) throws IOException {
  try {
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    if(account == null) {
      return badRequest("Account not found");
    }
    String newEmail = canonicalise(request.newEmail);
    if(!isValid(newEmail)) {
      return badRequest("Invalid e-mail: " + newEmail);
    }
    account.setEmail(newEmail);
    boolean updated = accountRepository.update(account);
    if(!updated) {
      return internalServerError("Failed to update account");
    }
    return ok("E-mail address updated");
  } catch (IOException.class) {
    return badRequest("Could not parse request");
  }
}
```

This is obviously awful, so we replaced it with a railway-oriented approach:

```java
public Response updateEmail(String requestBody) {
  return objectMapper.readValue(requestBody, EmailChangeRequest.class)
    .then(attempt(this::validateEmail))
    .then(onSuccess(Email::canonicalise))
    .then(attempt(req -> pair(accountRepository.get(req.id), req)))
    .then(onSuccess(pair -> pair.account.setEmail(pair.change.newEmail)))
    .then(attempt(accountRepository::update))
    .then(onSuccess(Response::ok))
    .then(ifFailed(reason -> Response.badRequest(reason)));
}
```

Which is obviously (to my eye, at least) much easier to read, understand, and maintain.
There's just one thing I've sort of skirted around.

That railway-oriented code assumes all those methods return `Results` - but they
don't. They do all the messy things that Java usually does, like throw exceptions
or return null.

I could argue "well, just refactor them to return `Results`", and sometimes that'll
be a perfectly cromulent approach. Other times refactoring that signature will
hit 20 other points in your codebase, and you don't want to make a change of that
scale right now. And other times you *can't* change the signature because it isn't
your signature, it's on an object provided by Spring or Jersey or some other
framework where you can't change anything.

Good news. That doesn't matter. Functions compose.

### Composing our way out of the problem

Let's take the example of `accountRepository.update()` to start with. Currently,
that looks like this:
```java
public boolean update(Account account) { /* internal distractions */ }
```

What we *want* is something which looks like:
```java
public Function<Account, Result<Account, String>> updateAccount() { /*whatever */ }
```

The simplest thing we could do is build something super-specific:
```java
public Function<Account, Result<Account, String>> updateAccount() {
  return account -> {
    boolean succeeded = accountRepository.update(account);
    if(succeeded) {
      return success(account);
    } else {
      return failure("Failed to update account");
    }
  };
}
```

And that would work. We could build these little translation-layer functions
close to the use-site of our railways. It would end up pretty verbose, but at
least there's a layer of abstraction so we can concentrate on the control flow
at the base and only look at these details when we really need to.

But we can do better, and go generic:

```java
public <S, F> Function<S, Result<S, F>> failWhenFalse(Predicate<S> op, F failure) {
  return value -> = op.test(value)) ? success(value) : failure(failure);
}
```

And perform that operation inline:

```java
public Response updateEmail(String requestBody) {
  return objectMapper.readValue(requestBody, EmailChangeRequest.class)
    .then(attempt(this::validateEmail))
    .then(onSuccess(Email::canonicalise))
    .then(attempt(req -> pair(accountRepository.get(req.id), req)))
    .then(onSuccess(pair -> pair.account.setEmail(pair.change.newEmail)))
    "!!blue!!".then(attempt(failWhenFalse(accountRepository::update, "Failed to update database")))"!!end!!"
    .then(onSuccess(Response::ok))
    .then(ifFailed(reason -> Response.badRequest(reason)));
}
```

Or maybe we don't want to perform it inline, in which case we can extract out
the wrapping, which at least is declarative about its intent:

```java
public Response updateEmail(String requestBody) {
  return objectMapper.readValue(requestBody, EmailChangeRequest.class)
    .then(attempt(this::validateEmail))
    .then(onSuccess(Email::canonicalise))
    .then(attempt(req -> pair(accountRepository.get(req.id), req)))
    .then(onSuccess(pair -> pair.account.setEmail(pair.change.newEmail)))
    .then(attempt(updateAccount()))
    .then(onSuccess(Response::ok))
    .then(ifFailed(reason -> Response.badRequest(reason)));
}

public static Function<Account, Result<Account, String>> updateAccount() {
  return failWhenFalse(accountRepository::update, "Failed to update database")
}
```

### There's more!

We can write a whole bunch of similar generic translators:

```java
// Note: only handles runtime exceptions. This can be extended to handle
// checked exceptions too.
public static <IS, OS, F> Function<IS, Result<OS, F>> failIfThrows(
  Function<IS, OS> f, F failure)
{
  return input -> {
    try {
      return success(f.apply(input));
    } catch(RuntimeException e) {
      return failure(failure);
    }
  };
}

public static <IS, OS, F> Function<IS, Result<OS, F>> failIfNull(
  Function<IS, OS> f, F failure)
{
  return input -> {
    result = f.apply(input);
    if(result != null) {
      return success(result);
    } else {
      return failure(failure);
    }
  }
}

public static <IS, OS, F> Function<IS, Result<OS, F>> failIfEmpty(
  Function<IS, Optional<OS>> f, F failure)
{
   return input -> f.apply(input)
     .map(Result::success)
     .orElse(failure(failure));
}
```

And in doing so, we can build up a set of shims to convert from the real world's
messy, inconsistent failure modes, to our idealised world using only the One
True Failure Representation.

We can build them each once, and add them to our toolset to be reused over and
over again. And if it turns out we missed something, it's easy enough to extend
the generic toolset locally, and pop it in a pull request for the library later.

Furthermore, we can do this *locally*, without having to propagate our ideas
any further than we're ready to. We don't need to change anything outside the
body of the method in question.

Heck, if we need to write a callback for a framework which expects an exception
on error: that's OK. I'll feel a little dirty, but we can convert a `Result` into
a success or a thrown exception:

```java
public static <S, F> Function<Result<S, F>, S> throwIfFailed(Supplier<? extends RuntimeException> f) {
  return result -> result.either(
    success -> success,
    failure -> f.get()
  );
}
```

And it all slots together neatly, because everything's built out of higher-order
functions, which (unlike methods) compose.

### Summing up

It's a pain that everyone doesn't represent the possibility of failure using
something as clean and principled as `Result`s. But that's OK - we can convert any
function which fails in any way to instead fail with `Result`s cleanly, easily,
and locally. And if we need to, we can convert a `Result` back into whatever messy
failure mode circumstances require.

So that's one less excuse!
