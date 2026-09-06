# Stripe compatibility

Read this with the dedicated Stripe skill for Stripe implementation, review,
or upgrade work. The native skill owns product and integration guidance; this
shared reference corrects version and SDK assumptions in bundled examples.
These corrections take precedence when those examples disagree. Do not edit
the installed plugin cache or copy its entire skill into another owner.

## Select the actual target

- Treat API dates and SDK tables labelled "latest" in a skill as unverified
  snapshots. Inspect the project's SDK, lockfile, request version, and webhook
  endpoint versions. Refresh the [current API version](https://docs.stripe.com/api/versioning.md)
  and the relevant stable SDK release through [Stripe's SDK links](https://docs.stripe.com/sdks.md)
  when an upgrade is requested. Do not silently upgrade an existing integration
  while answering an unrelated question.
- Use the user's target and a compatible SDK release. Modern server SDKs
  normally use the API version pinned by that SDK release. Omitting an explicit
  version is not automatically reliance on the account default. Older SDKs,
  direct HTTP requests, and CLI requests can have different defaults; verify
  the [version contract for the actual client](https://docs.stripe.com/sdks/set-version.md).
- Java, Go, and .NET use the SDK's fixed API version. Node TypeScript types and
  Python annotations also describe the SDK's release version. Do not force an
  incompatible version with a cast or suppress a type error; align the SDK and
  intended API version. Check webhook payload versions separately.

## Use the language's client API

Prefer a configured client instance and environment-provided credentials.
Constructor names differ: Node uses `new Stripe(key)`, Python uses
`StripeClient(key)`, and Ruby uses `Stripe::StripeClient.new(key)`.
Do not interpret "use StripeClient" as the same exported class in every SDK,
or claim every language's legacy globals have identical deprecation status.

For example, current Python uses `client.v1.customers.list()` and per-request
`options={"stripe_version": target_version}`. It does not pass legacy global
API arguments directly to the instance method. Check the installed signatures
and the [Python SDK's instance usage](https://github.com/stripe/stripe-python#usage).
Set an explicit version only through the actual SDK's supported option and
keep it compatible with the selected SDK.

## Keep browser and server versions compatible

Named Stripe.js releases select their own compatible API version; do not
assume their monthly date equals the server SDK's date or override it with a
date copied from a skill. Keep browser and server on the same release train
where possible and check the npm wrapper's mapping in the
[Stripe.js versioning guide](https://docs.stripe.com/sdks/stripejs-versioning.md).
Use its current support policy rather than promising indefinite v3 support.

Type-check the selected client options and request shape. For an authorized
integration upgrade, test the affected request and webhook flows in a sandbox
before changing live settings. Researching documentation alone does not require
creating a sandbox, generating keys, or changing account configuration.
