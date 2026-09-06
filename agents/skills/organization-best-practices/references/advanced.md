# Advanced Organization Configuration

Use the installed package's types and the current [Better Auth organization documentation](https://better-auth.com/docs/plugins/organization) as the final contract.

## Static Custom Roles

When extending the built-in resources, merge the default statements before creating the controller. Passing replacement roles for `owner`, `admin`, or `member` overrides their predefined permissions, so merge the corresponding built-in role statements when that is not intended.

```ts
import { createAccessControl } from "better-auth/plugins/access";
import {
  adminAc,
  defaultStatements,
  memberAc,
  ownerAc,
} from "better-auth/plugins/organization/access";

export const statements = {
  ...defaultStatements,
  project: ["create", "read", "update", "delete"],
} as const;

export const ac = createAccessControl(statements);
export const owner = ac.newRole({
  ...ownerAc.statements,
  project: ["create", "read", "update", "delete"],
});
export const admin = ac.newRole({
  ...adminAc.statements,
  project: ["create", "read", "update"],
});
export const member = ac.newRole({
  ...memberAc.statements,
  project: ["read"],
});
```

Pass `ac` and the same role definitions to `organization({...})` and `organizationClient({...})`.

## Dynamic Access Control

Dynamic roles require a predefined access controller on the server and dynamic access enabled on both server and client:

```ts
// server
organization({
  ac,
  roles: { owner, admin, member },
  dynamicAccessControl: { enabled: true },
});

// client
organizationClient({
  ac,
  roles: { owner, admin, member },
  dynamicAccessControl: { enabled: true },
});
```

Run the required migration to add the organization-role table.

```ts
await authClient.organization.createRole({
  role: "moderator",
  permission: {
    project: ["read", "update"],
  },
  organizationId,
});

await authClient.organization.updateRole({
  roleId,
  organizationId,
  data: {
    permission: {
      project: ["read"],
    },
  },
});
```

Use `hasPermission` for dynamic roles. The synchronous `checkRolePermission` method cannot include roles stored dynamically.

## Teams

Enable teams on both plugins:

```ts
organization({
  teams: {
    enabled: true,
    maximumTeams: 20,
    maximumMembersPerTeam: 50,
    allowRemovingAllTeams: false,
  },
});

organizationClient({
  teams: { enabled: true },
});
```

A team member must first belong to the organization. Setting an active team does not replace organization authorization.

## Lifecycle Hooks

Use the current `organizationHooks` option for new implementations. The older `organizationCreation` hooks are deprecated. Hooks may validate or transform organization, member, invitation, and team operations, but they should not replace endpoint authorization.

Keep hooks small and idempotent. For external side effects, use an outbox or retry-safe job after the database change rather than making the core auth operation depend on an unreliable service.

## Deletion

Set `disableOrganizationDeletion: true` when the product does not support destructive deletion. Otherwise use `organizationHooks.beforeDeleteOrganization` and `afterDeleteOrganization` for application cleanup or archival, and test partial-failure handling.
