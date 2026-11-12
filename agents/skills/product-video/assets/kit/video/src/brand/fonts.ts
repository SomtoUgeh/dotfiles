import { loadFont } from "@remotion/fonts";
import { staticFile } from "remotion";
import { brand } from "./tokens";

// Loads the font files listed in brand.fonts (public/fonts/<file>). With an empty list
// the video uses the system font named in tokens.ts.
export const fontsLoaded = Promise.all(
  brand.fonts.map((font) =>
    loadFont({ family: font.family, url: staticFile(`fonts/${font.file}`), weight: font.weight }),
  ),
);
