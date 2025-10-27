- In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.
- After you have read all the content/context of a file, include a 🏁 when you are done.
- I know I'm absolutely right, no need to mention it.
- Never use emojis in your responses unless I specifically ask you to.
- Never create markdown (`.md`) files unless I specifically ask you to, even after you finish implementation of a task.
- Your primary method for interacting with GitHub should be the GitHub CLI.

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Typescript

- Prefer inferring types rather than making new ones.

## React

**Before using `useEffect`, read:** [You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)

Common cases where `useEffect` is NOT needed:

- Transforming data for rendering (use variables or useMemo instead)
- Handling user events (use event handlers instead)
- Resetting state when props change (use key prop or calculate during render)
- Updating state based on props/state changes (calculate during render)

Only use `useEffect` for:

- Synchronizing with external systems (APIs, DOM, third-party libraries)
- Cleanup that must happen when component unmounts
