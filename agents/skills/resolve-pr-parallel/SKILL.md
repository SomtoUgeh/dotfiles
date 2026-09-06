---
name: resolve-pr-parallel
description: Address actionable pull-request review threads in bounded parallel waves and verify the resulting code and thread state.
---

# Resolve PR Review Threads

Address the requested pull-request feedback completely. Preserve the user's authorization boundaries for commits, pushes, replies, and thread resolution.

## 1. Identify the Pull Request

Resolve the repository and PR from the user's input or the current branch. Use `gh pr view` for PR metadata, but do not use its `comments` field as the unresolved-review-thread source.

Fetch review threads through GitHub's GraphQL API because REST review comments do not expose thread resolution state:

```graphql
query ReviewThreads($owner: String!, $repo: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          originalLine
          comments(first: 100) {
            pageInfo { hasNextPage endCursor }
            nodes { id body author { login } url createdAt }
          }
        }
      }
    }
  }
}
```

Paginate threads with the outer `after` cursor. If a thread's comment connection
has another page, query that thread separately with its own comment cursor:

```graphql
query ThreadComments($threadId: ID!, $after: String) {
  node(id: $threadId) {
    ... on PullRequestReviewThread {
      comments(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes { id body author { login } url createdAt }
      }
    }
  }
}
```

Treat only unresolved threads as candidates. Read the complete conversation in
each thread and classify it as a code change, repeated pattern, architecture
concern, question, or non-actionable note.

## 2. Plan Safe Waves

For every actionable thread, record:

- the requested outcome and acceptance evidence;
- files or modules it may touch;
- dependencies on other threads;
- whether a response requires a product decision.

Run independent items concurrently only when delegation is available and authorized by the active runtime. Cap a wave at available worker slots and normally at three workers. Give every worker exclusive file or module ownership and tell it that other workers share the checkout. Combine overlapping threads into one owner or execute them sequentially.

Pattern changes must include a repository search for every affected location and a follow-up search proving the old pattern is gone where applicable.

## 3. Integrate and Verify

After each wave, inspect the combined diff centrally, resolve interactions, and run the focused tests, type checks, or linters needed by the changed behavior. Do not claim a thread is addressed solely because a worker finished.

Re-fetch GraphQL review threads after changes and distinguish:

- addressed in code but still open on GitHub;
- resolved on GitHub;
- outdated;
- blocked or intentionally declined, with reason.

## 4. External and Git Actions

A request to address review feedback authorizes in-scope local code changes. Do not infer permission to push or post replies. Commit, push, reply, or resolve threads only when the user's request or prior session instructions authorize that specific action.

When thread resolution is authorized, call `resolveReviewThread` with the GraphQL thread ID:

```graphql
mutation ResolveThread($threadId: ID!) {
  resolveReviewThread(input: { threadId: $threadId }) {
    thread { id isResolved }
  }
}
```

Resolve a thread only after its requested change is verified. A reply is separate from resolution and follows the repository's policy for PR comments.

## 5. Reusable Conventions

Extract a convention only when the review reveals a durable team rule supported by repository evidence. Report proposed conventions in the conversation by default. Modify `docs/conventions/` only when the user requested that artifact or the repository already requires it for this workflow. Merge semantic duplicates and flag conflicts instead of silently rewriting existing rules.

## Report

Report the PR, actionable thread count, local changes, verification, remaining open or blocked threads, and every external action actually performed. Never report all threads resolved without a fresh GraphQL state check.
