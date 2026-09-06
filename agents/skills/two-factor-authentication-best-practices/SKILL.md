---
name: two-factor-authentication-best-practices
description: This skill provides guidance and enforcement rules for implementing secure two-factor authentication (2FA) using Better Auth's twoFactor plugin.
---

## Setting Up Two-Factor Authentication

When adding 2FA to your application, configure the `twoFactor` plugin with your app name as the issuer. This name appears in authenticator apps when users scan the QR code.

```ts
import { betterAuth } from "better-auth";
import { twoFactor } from "better-auth/plugins";

export const auth = betterAuth({
  appName: "My App", // Used as the default issuer for TOTP
  plugins: [
    twoFactor({
      issuer: "My App", // Optional: override the app name for 2FA specifically
    }),
  ],
});
```

After adding the plugin, follow the
[released schema workflow](../organization-best-practices/references/better-auth-1-7-migration.md).
For a new database or an already migrated 1.7 database, inspect `auth generate`
output, then use `auth migrate` with the built-in Kysely adapter or your ORM's
migration tooling with Prisma/Drizzle. Pin `auth` to the project's Better Auth
release; the older `@better-auth/cli` package is not the 1.7 CLI.

Published `auth@1.7.2` has no `migrate plan` or `migrate apply` actions, despite
the live website showing them. A populated 1.6 database requires the separate
manual data preparation in the linked reference before schema changes.

### Client-Side Setup

Add the client plugin and configure the redirect behavior for 2FA verification:

```ts
import { createAuthClient } from "better-auth/client";
import { twoFactorClient } from "better-auth/client/plugins";

export const authClient = createAuthClient({
  plugins: [
    twoFactorClient({
      onTwoFactorRedirect({ twoFactorMethods }) {
        sessionStorage.setItem("two-factor-methods", JSON.stringify(twoFactorMethods));
        window.location.href = "/2fa"; // Redirect to your 2FA verification page
      },
    }),
  ],
});
```

## Enabling 2FA for Users

When a user enables 2FA, require their password for credential accounts. Better Auth 1.7 accepts `method: "totp" | "otp"` and returns a discriminated result. TOTP returns a URI and backup codes; OTP does not.

```ts
const enable2FA = async (password: string) => {
  const { data, error } = await authClient.twoFactor.enable({
    password,
    method: "totp",
  });

  if (error || !data) {
    return { data: null, error };
  }

  if (data.method === "totp") {
    // Narrowed to { method: "totp", totpURI, backupCodes }.
    return { data, error: null };
  }

  // { method: "otp" }; OTP is active immediately.
  return { data, error: null };
};
```

For TOTP, `twoFactorEnabled` remains `false` until the user verifies the enrollment code, unless `skipVerificationOnEnable` is enabled. OTP becomes active immediately and requires `otpOptions.sendOTP` on the server. Render the QR code and backup-code step only after narrowing `data.method === "totp"`.

### Skipping Initial Verification

If you want TOTP to become active without enrollment-code verification, set `skipVerificationOnEnable`:

```ts
twoFactor({
  skipVerificationOnEnable: true, // Not recommended for most use cases
});
```

This does not confirm that the user successfully configured an authenticator app. It does not change OTP enrollment, which is already immediate.

## TOTP (Authenticator App)

TOTP generates time-based codes using an authenticator app (Google Authenticator, Authy, etc.). Codes are valid for 30 seconds by default.

### Displaying the QR Code

Use the TOTP URI to generate a QR code for users to scan:

```tsx
import QRCode from "react-qr-code";

const TotpSetup = ({ totpURI }: { totpURI: string }) => {
  return <QRCode value={totpURI} />;
};
```

### Verifying TOTP Codes

Better Auth accepts codes from one period before and one after the current time, accommodating minor clock differences between devices:

```ts
const verifyTotp = async (code: string) => {
  const { data, error } = await authClient.twoFactor.verifyTotp({
    code,
    trustDevice: true, // Optional: remember this device for 30 days
  });
};
```

### TOTP Configuration Options

```ts
twoFactor({
  totpOptions: {
    digits: 6, // 6 or 8 digits (default: 6)
    period: 30, // Code validity period in seconds (default: 30)
  },
});
```

## OTP (Email/SMS)

OTP sends a one-time code to the user's email or phone. You must implement the `sendOTP` function to deliver codes.

### Configuring OTP Delivery

```ts
import { betterAuth } from "better-auth";
import { twoFactor } from "better-auth/plugins";
import { sendEmail } from "./email";

export const auth = betterAuth({
  plugins: [
    twoFactor({
      otpOptions: {
        sendOTP: async ({ user, otp }, ctx) => {
          await sendEmail({
            to: user.email,
            subject: "Your verification code",
            text: `Your code is: ${otp}`,
          });
        },
        period: 5, // Code validity in minutes (default: 3)
        digits: 6, // Number of digits (default: 6)
        allowedAttempts: 5, // Max verification attempts (default: 5)
      },
    }),
  ],
});
```

### Sending and Verifying OTP

```ts
// Request an OTP to be sent
const sendOtp = async () => {
  const { data, error } = await authClient.twoFactor.sendOtp();
};

// Verify the OTP code
const verifyOtp = async (code: string) => {
  const { data, error } = await authClient.twoFactor.verifyOtp({
    code,
    trustDevice: true,
  });
};
```

### OTP Storage Security

Configure how OTP codes are stored in the database:

```ts
twoFactor({
  otpOptions: {
    storeOTP: "encrypted", // Options: "plain", "encrypted", "hashed"
  },
});
```

For custom encryption:

```ts
twoFactor({
  otpOptions: {
    storeOTP: {
      encrypt: async (token) => myEncrypt(token),
      decrypt: async (token) => myDecrypt(token),
    },
  },
});
```

## Backup Codes

Backup codes provide account recovery when users lose access to their authenticator app or phone. They are generated automatically during TOTP enrollment. OTP enrollment does not generate or return backup codes.

### Displaying Backup Codes

Show the returned backup codes during TOTP enrollment after narrowing the enable result to `method === "totp"`:

```tsx
const BackupCodes = ({ codes }: { codes: string[] }) => {
  return (
    <div>
      <p>Save these codes in a secure location:</p>
      <ul>
        {codes.map((code, i) => (
          <li key={i}>{code}</li>
        ))}
      </ul>
    </div>
  );
};
```

### Regenerating Backup Codes

When users need new codes, regenerate them (this invalidates all previous codes):

```ts
const regenerateBackupCodes = async (password: string) => {
  const { data, error } = await authClient.twoFactor.generateBackupCodes({
    password,
  });
  // data.backupCodes contains the new codes
};
```

### Using Backup Codes for Recovery

```ts
const verifyBackupCode = async (code: string) => {
  const { data, error } = await authClient.twoFactor.verifyBackupCode({
    code,
    trustDevice: true,
  });
};
```

**Note**: Each backup code can only be used once and is removed from the database after successful verification.

### Backup Code Configuration

```ts
twoFactor({
  backupCodeOptions: {
    amount: 10, // Number of codes to generate (default: 10)
    length: 10, // Length of each code (default: 10)
    storeBackupCodes: "encrypted", // Options: "plain", "encrypted"
  },
});
```

## Handling 2FA During Sign-In

When a user with 2FA enabled signs in, the response includes `twoFactorRedirect: true`:

```ts
const signIn = async (email: string, password: string) => {
  const { data, error } = await authClient.signIn.email(
    {
      email,
      password,
    },
    {
      onSuccess(context) {
        if (context.data.twoFactorRedirect) {
          // Redirect to 2FA verification page
          window.location.href = "/2fa";
        }
      },
    }
  );
};
```

### Server-Side 2FA Detection

When using `auth.api.signInEmail` on the server, check for 2FA redirect:

```ts
const response = await auth.api.signInEmail({
  body: {
    email: "user@example.com",
    password: "password",
  },
});

if ("twoFactorRedirect" in response) {
  // Handle 2FA verification
}
```

## Trusted Devices

Trusted devices allow users to skip 2FA verification on subsequent sign-ins for a configurable period.

### Enabling Trust on Verification

Pass `trustDevice: true` when verifying 2FA:

```ts
await authClient.twoFactor.verifyTotp({
  code: "123456",
  trustDevice: true,
});
```

### Configuring Trust Duration

```ts
twoFactor({
  trustDeviceMaxAge: 30 * 24 * 60 * 60, // 30 days in seconds (default)
});
```

**Note**: The trust period refreshes on each successful sign-in within the trust window.

## Security Considerations

### Session Management

During the 2FA flow:

1. User signs in with credentials
2. Session cookie is removed (not yet authenticated)
3. A temporary two-factor cookie is set (default: 10-minute expiration)
4. User verifies via TOTP, OTP, or backup code
5. Session cookie is created upon successful verification

Configure the two-factor cookie expiration:

```ts
twoFactor({
  twoFactorCookieMaxAge: 600, // 10 minutes in seconds (default)
});
```

### Rate Limiting

Keep endpoint rate limiting enabled. Add `allowedAttempts` to the existing
`otpOptions` configuration that already supplies `sendOTP`; it limits guesses
against one issued OTP code. Better Auth 1.7 also supports account-level
lockout across TOTP, OTP, and backup-code failures:

```ts
twoFactor({
  otpOptions: {
    allowedAttempts: 5,
  },
  accountLockout: {
    enabled: true,
    maxFailedAttempts: 10,
    durationSeconds: 15 * 60,
  },
});
```

A successful second-factor verification resets the account counter. Locked attempts return `429` with `ACCOUNT_TEMPORARILY_LOCKED`. Endpoint throttling, per-code attempt limits, and account lockout are separate controls.

### Encryption at Rest

- TOTP secrets are encrypted using symmetric encryption with your auth secret
- Backup codes are stored encrypted by default
- OTP codes can be configured for plain, encrypted, or hashed storage

### Constant-Time Comparison

Better Auth uses constant-time comparison for OTP verification to prevent timing attacks.

### Credential Account Requirement

By default, enabling and managing 2FA requires a credential account. Set `allowPasswordless: true` only when the product intentionally allows passwordless users to manage 2FA; a password remains required whenever the user has a credential account. This option does not make OAuth or other passwordless sign-in endpoints pass through the 2FA challenge automatically.

## Disabling 2FA

Allow users to disable 2FA with password confirmation:

```ts
const disable2FA = async (password: string) => {
  const { data, error } = await authClient.twoFactor.disable({
    password,
  });
};
```

**Note**: When 2FA is disabled, trusted device records are revoked.

## Complete Configuration Example

```ts
import { betterAuth } from "better-auth";
import { twoFactor } from "better-auth/plugins";
import { sendEmail } from "./email";

export const auth = betterAuth({
  appName: "My App",
  plugins: [
    twoFactor({
      // TOTP settings
      issuer: "My App",
      totpOptions: {
        digits: 6,
        period: 30,
      },
      // OTP settings
      otpOptions: {
        sendOTP: async ({ user, otp }) => {
          await sendEmail({
            to: user.email,
            subject: "Your verification code",
            text: `Your code is: ${otp}`,
          });
        },
        period: 5,
        allowedAttempts: 5,
        storeOTP: "encrypted",
      },
      accountLockout: {
        enabled: true,
        maxFailedAttempts: 10,
        durationSeconds: 15 * 60,
      },
      // Backup code settings
      backupCodeOptions: {
        amount: 10,
        length: 10,
        storeBackupCodes: "encrypted",
      },
      // Session settings
      twoFactorCookieMaxAge: 600, // 10 minutes
      trustDeviceMaxAge: 30 * 24 * 60 * 60, // 30 days
    }),
  ],
});
```
