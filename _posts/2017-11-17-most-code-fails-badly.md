---
layout: post
title: Most Code Fails Badly - The Case for Results
author: Tom Johnson
published: true
excerpt_separator: <!--more-->
---
In the real world, most code fails. That's not a bad thing per se:
the real world is hairy and complex, and occasionally things will
happen that aren't as expected.

Failures happen. There's not much we can do about that. What we
can do, though, is try and ensure our handling of failures is
as good as possible.

However, most code that fails, fails badly.

<!--more-->

As an example, take this simple method, which changes the e-mail
address on a customer account:

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
We:
 - read a request from a JSON body into a domain class
 - load the associated account from our repository
 - clean up the e-mail into a canonical format
 - set the new e-mail on the account
 - persist the changeRequest
 - and confirm the action succeeded.

This can fail at a number of points, and we have no handling
for that. Let's fix that.

Firstly, our input could be malformed - we may receive some JSON that
can't be mapped to our change request object, or even some invalid
JSON:
```java
public Response updateEmail(String requestBody) throws IOException {
  "!!pink!!"try {"!!end!!"
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    String newEmail = canonicalise(request.newEmail);
    account.setEmail(newEmail);
    accountRepository.update(account);
    return ok("E-mail address updated");
  "!!pink!!"} catch (IOException.class) {
    return badRequest("Could not parse request");
  }"!!end!!"
}
```
The account number provided might not exist:
```java
public Response updateEmail(String requestBody) throws IOException {
  try {
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    "!!pink!!"if(account == null) {
      return badRequest("Account not found");
    }"!!end!!"
    String newEmail = canonicalise(request.newEmail);
    account.setEmail(newEmail);
    accountRepository.update(account);
    return ok("E-mail address updated");
  } catch (IOException.class) {
    return badRequest("Could not parse request");
  }
}
```
The e-mail address might be invalid:
```java
public Response updateEmail(String requestBody) throws IOException {
  try {
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    if(account == null) {
      return badRequest("Account not found");
    }
    String newEmail = canonicalise(request.newEmail);
    "!!pink!!"if(!isValid(newEmail)) {
      return badRequest("Invalid e-mail: " + newEmail);
    }"!!end!!"
    account.setEmail(newEmail);
    accountRepository.update(account);
    return ok("E-mail address updated");
  } catch (IOException.class) {
    return badRequest("Could not parse request");
  }
}
```
And the update might not persist successfully:
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
    "!!pink!!"boolean updated ="!!end!!" accountRepository.update(account);
    "!!pink!!"if(!updated) {
      return internalServerError("Failed to update account");
    }"!!end!!"
    return ok("E-mail address updated");
  } catch (IOException.class) {
    return badRequest("Could not parse request");
  }
}
```

I would describe the result of these checks as code which fails badly.
Our code is much longer, and that's bad. More importantly, our error
handling is all intermingled with our happy path:
```java
public Response updateEmail(String requestBody) throws IOException {
  "!!pink!!"try {"!!end!!"
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    "!!pink!!"if(account == null) {
      return badRequest("Account not found");
    }"!!end!!"
    String newEmail = canonicalise(request.newEmail);
    "!!pink!!"if(!isValid(newEmail)) {
      return badRequest("Invalid e-mail: " + newEmail);
    }"!!end!!"
    account.setEmail(newEmail);
    "!!pink!!"boolean updated ="!!end!!" accountRepository.update(account);
    "!!pink!!"if(!updated) {
      return internalServerError("Failed to update account");
    }"!!end!!"
    return ok("E-mail address updated");
  "!!pink!!"} catch (IOException.class) {
    return badRequest("Could not parse request");
  }"!!end!!"
}
```
All the pink code is error-handling code. It's gotten to the point
where it's hard to see what we're trying to actually do here, hidden
amongst our failure cases. Reading the code is a constant context-
switching exercise.

Furthermore, we're constantly switching between different failure
models - exceptions, null returns, explicit checks, and return codes.

This is code I would describe as failing badly. But what's the
alternative?

Here's one:

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

For comparison, here's the implementation *without any error handling*, which
is of a similar size and complexity:

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

This implements all the same logic, only it uses the
`Result` type from the [co.unruly.control](https://github.com/unruly/control)
library to encapsulate failure conditions. Not that you'd notice immediately -
there's no mention of `Result` in the code.

Over a series of upcoming posts, I'm going to explain and justify this approach,
but in brief, it gives us three key advantages over the more typical error
handling described above:

Firstly, it's **concise**. It's barely longer than the code which doesn't
address failure cases at all. That's not necessarily an advantage if
it comes at the cost of readability, of course - but all other things
being equal, the shorter the better.

Secondly, it's **coherent**. Everything that can fail here does so by
either returning a `Success` or a `Failure`, instead of having to deal with
multiple different failure mechanisms (all of which are flawed).

Thirdly, it's **contained**. The error-handling mechanisms live outside the
actual work we're trying to do. If we highlight the error-handling code here,
we get something far more orderly:

```java
public Response updateEmail(String requestBody) {
  return objectMapper.readValue(requestBody, EmailChangeRequest.class)
    "!!pink!!".then(attempt"!!end!!"(this::validateEmail))
    "!!pink!!".then(onSuccess"!!end!!"(Email::canonicalise))
    "!!pink!!".then(attempt"!!end!!"(req -> pair(accountRepository.get(req.id), req)))
    "!!pink!!".then(onSuccess"!!end!!"(pair -> pair.account.setEmail(pair.change.newEmail)))
    "!!pink!!".then(attempt"!!end!!"(accountRepository::update))
    "!!pink!!".then(onSuccess"!!end!!"(Response::ok))
    "!!pink!!".then(ifFailed(reason -> Response.badRequest(reason)));"!!end!!"
}
```

And, for comparison again, the more traditional approach:

```java
public Response updateEmail(String requestBody) throws IOException {
  "!!pink!!"try {"!!end!!"
    EmailChangeRequest request = objectMapper.readValue(requestBody, EmailChangeRequest.class);
    Account account = accountRepository.get(request.accountId);
    "!!pink!!"if(account == null) {
      return badRequest("Account not found");
    }"!!end!!"
    String newEmail = canonicalise(request.newEmail);
    "!!pink!!"if(!isValid(newEmail)) {
      return badRequest("Invalid e-mail: " + newEmail);
    }"!!end!!"
    account.setEmail(newEmail);
    "!!pink!!"boolean updated ="!!end!!" accountRepository.update(account);
    "!!pink!!"if(!updated) {
      return internalServerError("Failed to update account");
    }"!!end!!"
    return ok("E-mail address updated");
  "!!pink!!"} catch (IOException.class) {
    return badRequest("Could not parse request");
  }"!!end!!"
}
```

So, that's where we're going to end up. In order to get there, I'll be discussing
the following in upcoming posts:
 - What a Result is, and why we need it
 - Carpet-oriented programming with Optionals
 - Programming with functions in Java, and the Applicable pattern
 - Railway-oriented programming with Results
