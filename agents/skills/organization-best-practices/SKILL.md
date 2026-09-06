---
name: organization-best-practices
description: Implement Better Auth organizations, memberships, invitations, teams, and role-based access control using the current organization plugin API.
---

# Better Auth Organizations

Use the project's installed Better Auth version and the current [official organization documentation](https://better-auth.com/docs/plugins/organization) as the contract. Inspect local types when the installed version differs from the current docs.

## Baseline Setup

```ts
import { betterAuth } from "better-auth";
import { organization } from "better-auth/plugins";

export const auth = betterAuth({
  plugins: [
    organization({
      allowUserToCreateOrganization: true,
      organizationLimit: 5,
      membershipLimit: 100,
    }),
  ],
});
```

```ts
import { createAuthClient } from "better-auth/client";
import { organizationClient } from "better-auth/client/plugins";

export const authClient = createAuthClient({
  plugins: [organizationClient()],
});
```

For a new database or a plugin addition to an already migrated 1.7 database,
use the released CLI's schema workflow: `auth generate` to inspect the SQL,
then `auth migrate` for the built-in Kysely adapter; Prisma and Drizzle use
`auth generate` followed by their own migration tooling. Pin the CLI to the
project's Better Auth release. The exact commands and separate procedure for
populated 1.6 data are in
[references/better-auth-1-7-migration.md](references/better-auth-1-7-migration.md).
The published 1.7.2 CLI does not implement the live website's `migrate plan`
or `migrate apply` commands.

## Creation Limits

`allowUserToCreateOrganization` answers whether creation is allowed. A function-valued `organizationLimit` answers whether the user has already reached the limit; it does not return a numeric limit.

```ts
organization({
  allowUserToCreateOrganization: (user) => user.emailVerified,
  organizationLimit: async (user) => {
    const count = await countOrganizationsForUser(user.id);
    const limit = user.plan === "premium" ? 20 : 3;
    return count >= limit;
  },
});
```

## Organization Context

Set the active organization after the user chooses it, or pass `organizationId` explicitly:

```ts
await authClient.organization.setActive({ organizationId });
await authClient.organization.listMembers({ query: { organizationId } });
```

Do not trust a client-provided organization ID by itself. Every server operation must authenticate the session and enforce membership and permission for that organization.

Creating an organization for another user is server-only. Call `auth.api.createOrganization` without session headers and pass `userId`. If session headers are present, the current docs say `userId` is ignored.

## Members and Invitations

Direct member addition is server-only:

```ts
await auth.api.addMember({
  body: {
    userId,
    role: "member",
    organizationId,
  },
});
```

For normal onboarding, configure `sendInvitationEmail` and call `inviteMember`. Build the acceptance URL from the invitation ID in the email callback:

```ts
organization({
  sendInvitationEmail: async ({ id, email, organization }) => {
    const url = new URL("/accept-invitation", process.env.APP_URL);
    url.searchParams.set("invitationId", id);
    await sendInvitation({ to: email, organizationName: organization.name, url });
  },
});
```

```ts
await authClient.organization.inviteMember({
  email: "person@example.com",
  role: "member",
  organizationId,
});

await authClient.organization.acceptInvitation({ invitationId });
```

The organization client does not expose a current `getInvitationURL` method. Generate and deliver the URL in application code.

## Permission Checks

Permission APIs take a resource-to-actions object:

```ts
const result = await authClient.organization.hasPermission({
  permissions: {
    member: ["create", "update"],
  },
});

if (result.data?.success) {
  // Render or perform the permitted action.
}
```

Use `hasPermission` for authorization that can include dynamic roles. `checkRolePermission` is a synchronous client-side convenience for configured static roles and must not guard server data by itself.

For custom resources, define an access controller and pass the same controller and static roles to both server and client plugins:

```ts
import { createAccessControl } from "better-auth/plugins/access";

export const statement = {
  project: ["create", "read", "update", "delete"],
} as const;

export const ac = createAccessControl(statement);
export const projectMember = ac.newRole({ project: ["read"] });
```

Read [references/advanced.md](references/advanced.md) when adding static custom roles, dynamic organization roles, teams, lifecycle hooks, or deletion controls.

## Security Invariants

- Scope every query and mutation to an authenticated organization membership.
- Enforce permissions on the server even when the UI hides an action.
- Preserve at least one owner and require an explicit ownership transfer.
- Treat invitations as expiring, single-purpose credentials bound to the invited address.
- Confirm destructive organization deletion and account for dependent application data.
- Test cross-tenant access, role changes, expired invitations, and last-owner behavior.
