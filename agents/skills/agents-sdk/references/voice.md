# Voice (Experimental)

Fetch https://developers.cloudflare.com/agents/api-reference/voice/ for complete documentation.

`@cloudflare/voice` — real-time speech-to-text and text-to-speech for agents. Audio streams over WebSocket.

```bash
npm install @cloudflare/voice
```

## Server

```typescript
import { Agent } from "agents";
import { withVoice, WorkersAITTS, WorkersAINova3STT, type VoiceTurnContext } from "@cloudflare/voice";
import { streamText } from "ai";
import { createWorkersAI } from "workers-ai-provider";

interface Env { AI: Ai }

export class VoiceAgent extends withVoice(Agent)<Env> {
  transcriber = new WorkersAINova3STT(this.env.AI);
  tts = new WorkersAITTS(this.env.AI);

  async onTurn(transcript: string, context: VoiceTurnContext) {
    const result = streamText({
      model: createWorkersAI({ binding: this.env.AI })("@cf/meta/llama-4-scout-17b-16e-instruct"),
      abortSignal: context.signal,
      system: "You are a voice assistant.",
      messages: [
        ...context.messages,
        { role: "user", content: transcript }
      ]
    });

    return result.textStream;
  }
}
```

## Lifecycle Hooks

| Hook | Purpose |
|------|---------|
| `onTurn(transcript, ctx)` | Handle transcribed speech (required) |
| `beforeCallStart(conn)` | Auth/validation before call starts |
| `onCallStart(conn)` | Call connected |
| `onCallEnd(conn)` | Call disconnected |
| `onInterrupt()` | User interrupted agent speech |

## Client (React)

```tsx
import { useVoiceAgent } from "@cloudflare/voice/react";

function VoiceUI() {
  const { status, startCall, endCall } = useVoiceAgent({
    agent: "VoiceAgent",
    name: "session-1"
  });

  return <button onClick={status === "idle" ? startCall : endCall}>
    {status === "idle" ? "Start Call" : "End Call"}
  </button>;
}
```

## STT/TTS Providers

Workers AI (default), Deepgram, ElevenLabs — install the provider package and swap the `transcriber`/`tts` properties.
