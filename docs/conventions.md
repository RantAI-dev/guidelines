# Conventions across codebases

The things that should be the same in every RantAI repository: the error body, HTTP statuses,
error codes, messages, field names, lists, timestamps, ids, headers, logs, configuration, commit
subjects. The rules themselves are one page, [template/docs/conventions.md](../template/docs/conventions.md),
which is copied into every project. This page says why each rule is what it is. Sources are in
[sources.md](sources.md).

Most of these choices have no right answer. The value is in making each of them once. A person or
an agent that moves between repositories should not have to find out again how an error looks.
Where we found no evidence, we took what most of our own code already does, or what costs least to
follow, and we say so.

Evidence tags are those of [engineering.md](engineering.md), plus two:

- **standard** — an RFC or a published specification says it.
- **survey** — what our own repositories do, counted on 11 November 2026.

## What our repositories do today

Four services with an HTTP API, read on 11 November 2026.

| Question | Found |
|---|---|
| Error body | Two shapes. `{"error": "text"}` in three services, `{"error": {"message", "type", "code"}}` in the one that serves an OpenAI-compatible API. That one drops `type` and `code` when the error comes inside a stream. |
| A code a client can branch on | No service has a registry of codes. One puts code-like strings and full sentences in the same field. |
| Status for a bad request | 400 everywhere. Two services also use 422, and the line between the two is not the same in both. |
| Another tenant's resource | 404 in both multi-tenant services. |
| Field names | camelCase in three. snake_case in the fourth, where the OpenAI protocol sets it. One camelCase service still sends some snake_case fields, from JSON built by hand. |
| Lists | A named key, `items` with page counts, a cursor, and bare arrays: four styles, all present inside one service. One list stops at a fixed number of rows without telling the caller, and one has a limit and no way to ask for the next page. |
| Request id | None. No service reads, makes or returns one. |
| Log fields | Across two services the tenant is `tenant` 107 times and `tenant_id` 69 times; the error is `error` or `err`. One of the three services that log writes JSON. |
| Health path | `/health` in three, each with a different body. None in the fourth. |
| Commit subjects | Conventional Commits in all three repositories with history. One sometimes puts a ticket id before the type. |

The most common defect was internal text in an error message: an exception, a driver error or an
upstream response passed to the caller as it came.

## The decisions

**1. One error body: `{"error": {"code", "message", "requestId"}}`, built by one function.**
`errors` lists bad fields and `details` carries facts for one code.
*Evidence:* judgement for the shape, standard for the parts.

We considered RFC 9457, the IETF format (`application/problem+json`) with the members `type`,
`title`, `status`, `detail` and `instance`. We did not take it, for three reasons. It names a
problem with a `type` URI, which we would have to host; left out, it means `about:blank`, which the
RFC defines as "no additional semantics beyond that of the HTTP status code", so a `code` member is
needed anyway. It has two texts for a person, `title` and `detail`, and a cheap model has to decide
what goes where. And one of our services must serve an OpenAI-compatible API, whose errors are
already an `error` object with a `message`; a second, unrelated family beside it is one more thing
to get wrong. Stripe's error is the same kind of object: `type`, `code`, `message`, `param`.

We kept three things from the RFC. Its example lists validation failures as an `errors` array with
a JSON Pointer per entry. It says "Consumers SHOULD NOT parse the "detail" member for information".
And it warns against making "implementation details such as a stack dump" available through the
interface.

**2. A code is a row in one registry, and the code that returns it is generated from that row.**
`.agents/error-codes.tsv` holds code, status and default message. `scripts/error-codes.sh` writes a
TypeScript, Rust or Python file from it, so a handler can only name a code that exists. Thirteen
codes are the same in every repository; a project adds its own.
*Enforced by* `scripts/error-codes.sh`, inside `scripts/check.sh`: the registry is well formed, the
thirteen shared rows are untouched, the generated files are current, and a code that has reached the
main branch keeps its name and status. *Evidence:* standard and survey. Google's API guidance says
machine-readable information "is critical so that machine actors do not need to parse error
messages", and "Services must use the same (reason, domain) pair for the same error". Google writes
its reasons in upper case; ours are lower `snake_case`, like our enum values.

Add a code only when a client would do something different on seeing it. `email_taken` earns a row;
`document_not_found` does not, because `not_found` on a document URL already says it.

**3. A fixed table of statuses.** One row per situation, in the rule sheet.
*Evidence:* standard for the meanings, judgement for what we leave out.

- **401 and 403.** RFC 9110: a 401 response "MUST send a WWW-Authenticate header field". 403 means
  the server "understood the request but refuses to fulfill it".
- **404 for another tenant's resource.** RFC 9110 allows it: a server "that wishes to "hide" the
  current existence of a forbidden target resource MAY instead respond with a status code of 404".
  Both of our multi-tenant services already do this. The body must be the same as for a missing
  resource, or the difference gives it away.
- **No 422.** RFC 9110 defines 422 for a request whose syntax is correct but whose "contained
  instructions" cannot be processed. Where that line falls is decided again in every handler, and
  our survey shows it drifting. Stripe describes 400 as "The request was unacceptable, often due to
  missing a required parameter". One status for "the request is wrong" needs no decision; the
  `errors` list says what is wrong. Frameworks disagree: some JSON extractors answer 422 on their
  own, so their rejection has to go through our function.
- **No 408.** It means the server "did not receive a complete request message within the time that
  it was prepared to wait". That is a slow client. Our own deadline running out is 504.
- **502 and 504 for any dependency.** The RFC defines both for a server "acting as a gateway or
  proxy". We use them whenever a service we call fails or is too slow. That reading is ours.
- **429 and 503 carry `Retry-After`.** RFC 6585 and RFC 9110 both say the server MAY send it. We
  always do, because a client or an agent that retries needs a number.

**4. A message is for a person, and nothing internal goes in it.**
*Evidence:* standard. Google: messages "should be brief but actionable" and "must not assume that
the user will know anything about its underlying implementation". The developer-facing message
"should be in English"; text shown to an end user is localized separately. So a user interface in
another language picks its own text by `code`, and identifiers stay English everywhere. One of our
services has field names in another language, which a person from the next team cannot guess.

Tests assert on the status and the code, never on the text. Then a message can be reworded without
a test failing, and nobody is tempted to match on it. *Evidence:* judgement.

**5. JSON fields are `camelCase`. Enum values and error codes are lower `snake_case`.**
*Evidence:* survey and judgement. Decided by the owner on 11 November 2026. Every API we designed
ourselves is already camelCase, and our consoles are TypeScript. The other choice, snake_case, needs
no translation in Rust, Python and SQL and is what Zalando's guideline requires ("property names
must be snake_case (and never camelCase)"). We did not take it, because it would leave our main
products as exceptions to our own rule until each gets a new API version.

camelCase has one known cost. In Rust the wire name differs from the field name, so every type
needs a rename attribute, and where JSON is built by hand the attribute is not there: that is how
one service came to send `created_at` inside camelCase responses. So the rule comes with a check:
no JSON built by hand in a handler, and a contract test that fails on any response key containing
`_`. Database columns and log fields stay snake_case; they never reach a client.

**6. Instants are RFC 3339 in UTC with exactly three decimals.**
*Evidence:* bench and standard. In our own bench a plan said "sorted by `createdAt` ascending".
The schema allowed both `…00Z` and `…00.500Z`, and `.` sorts before `Z`, so a string sort put a
later order first. Our reference solution had the defect and three reviewers found it. A fixed
width makes string order equal time order.

**7. Every list is `{"data": [...], "nextCursor": ...}` from its first release.**
*Evidence:* standard and survey. Google: "RPCs returning collections must provide pagination at the
outset", because adding it later is "a backwards-incompatible change"; a page size above the
maximum "should" be coerced down, a negative one "must" be an error, and tokens "must be opaque".
Zalando prefers cursors to offsets. A bare array cannot gain a field later, and a list cut at a
fixed length with no cursor loses rows without telling anyone; we found both.

**8. Every request has an id, and it is in the response header, the error body and every log
line.** *Evidence:* judgement, and survey: none of our services has one. When nobody reads the
code, the request id is how a report from a client is matched to a log line.

**9. `/health` and `/ready`.** Liveness checks nothing but the process; readiness checks the
dependencies and answers 503 when one is down. *Evidence:* judgement. There is no standard. We took
`/health` because three of four services already serve it.

**10. Logs are JSON lines with fixed field names.** *Evidence:* survey and judgement. Two names for
the tenant in one codebase means half the lines are missed by any search. A 4xx is `info`: a
caller's mistake is not a warning about our service, and warnings that fire all day are not read.

**11. Configuration is named one way and parsed once at startup.** *Evidence:* survey. All three of
our Rust services already build a typed config at startup and stop on a bad value. Prefixes and
`.env.example` are what differ.

**12. Commit subjects follow Conventional Commits.** *Evidence:* standard and survey. The
specification defines `feat` and `fix` and allows other types; we fix the list at ten so the hook
can check it. *Enforced by* `.githooks/commit-msg`. The commits in this repository before
11 November 2026 do not follow it.

**13. Money is an integer in the smallest unit, and an id is an opaque string.**
*Evidence:* judgement. Zalando uses a decimal amount with a currency code instead; both avoid
floats. We chose the integer because every language we use adds integers exactly. One of our
services cuts ids from the first twelve characters of a hash, which is 48 bits and will collide.

**14. Someone else's protocol is followed exactly.** An OpenAI-compatible route returns that API's
error shape, not ours. A client library written for that protocol must work unchanged.
*Evidence:* judgement.

## What is checked, and what is not

| Rule | Checked by |
|---|---|
| Codes come from the registry; a published code keeps its name and status; shared codes are identical everywhere | `scripts/error-codes.sh` in the gate |
| A handler can only return a registered code | the compiler, once handlers use the generated type |
| Commit subject | `.githooks/commit-msg` |
| Everything else on the sheet | the reviewer, who is told to check new endpoints against it |

That last row is weak, and we know it. The cheap fix is one contract test per service: for every
route, send a request with no credentials and one with a broken body, and assert that the answer
has the right status and matches the error schema, with no key outside it and no `_` in any key.
Put it in `tests/contract/`, which workers cannot edit. `stacks/typescript/api-error.ts` and
`stacks/rust/api_error.rs` are the function that builds the body; copy one of them.

## An API that already exists

Do not break clients to become consistent. The `adopt-guidelines` skill has a step for this:

1. Fix at once what no client can depend on: internal text in messages, a missing request id, log
   field names, undocumented configuration.
2. List every difference in shape, field name or status in the last section of the project's
   `docs/conventions.md`. The owner reads that list once.
3. Change them together at the next API version.

## Not tested

We have not measured whether a worker given this sheet follows it. The registry check and the
commit hook are tested in `scripts/selftest.sh`; the two helper files were compiled and run once,
by hand, on 11 November 2026 (TypeScript 5.6 with Bun, and axum 0.8.9).
