import type { VideoScript } from "./types";

/**
 * Example video for the kit's own test page (capture/example-site). It shows each scene
 * kind once. Replace it with your product's scripts.
 *
 * Footage plays at recorded speed. Each voice passage is a complete paragraph and is
 * sized to its footage at about 2.4 words a second.
 */
export const example = {
  id: "example",
  scenes: [
    {
      id: "intro",
      kind: "intro",
      title: "Set up in one minute",
      subtitle: "A short tour of the sign-up flow.",
      voice:
        "This short tour shows how a new customer creates a workspace. It takes less than one minute.",
    },
    {
      id: "chapter-signup",
      kind: "chapter",
      eyebrow: "Step one",
      title: "Create a workspace",
      voice: "Meet Maya. She runs a small studio, and she wants a workspace for her team.",
    },
    {
      id: "signup",
      kind: "app",
      clip: "example-01-signup",
      from: "form",
      to: "submit",
      caption: "Three fields",
      voice:
        "Maya enters her name and her work email. Then she selects the plan for a small team. The form asks for nothing else.",
    },
    {
      id: "submit",
      kind: "app",
      clip: "example-01-signup",
      from: "submit",
      to: "dashboard",
      caption: "One click",
      voice: "She selects the button, and the workspace is ready.",
    },
    {
      id: "dashboard",
      kind: "app",
      clip: "example-01-signup",
      from: "dashboard",
      to: "end",
      caption: "Ready to use",
      zoom: "off",
      voice:
        "Her new home page lists the next steps: invite the team, connect a calendar, and create the first project.",
    },
    {
      id: "outro",
      kind: "outro",
      tagline: "Start your workspace today.",
      url: "app.example.com",
      voice: "That is the complete sign-up flow. You can start your own workspace today.",
    },
  ],
} as const satisfies VideoScript;
