import { Composition } from "remotion";
import "./brand/fonts";
import { canvas } from "./brand/tokens";
import { scripts, type ScriptId } from "./script";
import { ScriptVideo } from "./video/ScriptVideo";
import { calculateScriptMetadata } from "./video/timeline";

const scriptIds = Object.keys(scripts) as ScriptId[];

/**
 * One composition per script registered in src/script/index.ts. The composition id is the
 * script id, so `remotion render example out/example.mp4` renders src/script/example.ts.
 * The real length comes from calculateMetadata; durationInFrames here is a placeholder.
 */
export const RemotionRoot: React.FC = () => (
  <>
    {scriptIds.map((scriptId) => (
      <Composition
        key={scriptId}
        id={scriptId}
        component={ScriptVideo}
        width={canvas.width}
        height={canvas.height}
        fps={canvas.fps}
        durationInFrames={30 * 60}
        defaultProps={{ scriptId, voiceVariant: "", resolved: null }}
        calculateMetadata={calculateScriptMetadata}
      />
    ))}
  </>
);
