import { Audio } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { AbsoluteFill } from "remotion";
import { color, fontFamily } from "../brand/tokens";
import { AppShot } from "../components/AppShot";
import { ChapterCard, IntroCard, OutroCard } from "../components/Cards";
import type { ResolvedScene, ScriptVideoProps } from "./timeline";

const SceneView: React.FC<{ readonly s: ResolvedScene }> = ({ s }) => {
  const { scene } = s;
  switch (scene.kind) {
    case "intro":
      return <IntroCard title={scene.title} subtitle={scene.subtitle} />;
    case "chapter":
      return <ChapterCard title={scene.title} eyebrow={scene.eyebrow} />;
    case "outro":
      return <OutroCard tagline={scene.tagline} url={scene.url} />;
    case "app":
      if (!s.app) return null;
      return (
        <AppShot
          clip={s.app.clip}
          src={s.app.src}
          playback={s.app.playback}
          sceneFrames={s.durationInFrames}
          transitionInFrames={s.transitionInFrames}
          transitionOutFrames={s.transitionOutFrames}
          zoom={scene.zoom}
          caption={scene.caption}
          eyebrow={scene.eyebrow}
          captionPlacement={scene.captionPlacement}
        />
      );
  }
};

/**
 * Generic video built from a script (src/script/*.ts). calculateMetadata resolves scene
 * lengths from voiceover audio and footage plans from clip events; this only renders them.
 */
export const ScriptVideo: React.FC<ScriptVideoProps> = ({ resolved }) => {
  if (!resolved) return null;
  return (
    <AbsoluteFill style={{ backgroundColor: color.background, fontFamily }}>
      <TransitionSeries name="Scenes">
        {resolved.scenes.flatMap((s, i) => {
          const sequence = (
            <TransitionSeries.Sequence
              key={s.scene.id}
              name={s.scene.id}
              durationInFrames={s.durationInFrames}
            >
              <SceneView s={s} />
              {s.voice ? (
                <Audio name={`${s.scene.id} voice`} src={s.voice.src} from={s.voice.startFrame} />
              ) : null}
            </TransitionSeries.Sequence>
          );
          if (i === resolved.scenes.length - 1) return [sequence];
          return [
            sequence,
            <TransitionSeries.Transition
              key={`${s.scene.id}-out`}
              presentation={fade()}
              timing={linearTiming({ durationInFrames: resolved.transitionFrames })}
            />,
          ];
        })}
      </TransitionSeries>
    </AbsoluteFill>
  );
};
