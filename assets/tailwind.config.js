// This file is for editor extensions and tools.
// Your project's Tailwind CSS build is configured in `assets/css/app.css`.

const plugin = require("tailwindcss/plugin");

module.exports = {
  content: [
    "./js/**/*.js",
    "./css/**/*.css",
    "../lib/najva_web.ex",
    "../lib/najva_web/**/*.ex",
    "../lib/najva_web/**/*.heex",
    "../lib/najva_web/**/*.eex",
  ],
  theme: {
    // extend: {},
  },
  plugins: [
//     // This is the daisyUI plugin from `assets/vendor/daisyui.js`
//     require("./vendor/daisyui.js")({
//       themes: "all",
//     }),
// 
//     // This is the heroicons plugin from `assets/vendor/heroicons.js`
//     require("./vendor/heroicons.js"),
// 
//     // Custom variants for Phoenix LiveView.
//     plugin(function ({ addVariant }) {
//       addVariant("phx-no-feedback", ["&.phx-no-feedback", ".phx-no-feedback &"]);
//       addVariant("phx-click-loading", ["&.phx-click-loading", ".phx-click-loading &"]);
//       addVariant("phx-submit-loading", ["&.phx-submit-loading", ".phx-submit-loading &"]);
//       addVariant("phx-change-loading", ["&.phx-change-loading", ".phx-change-loading &"]);
//     }),
  ],
};

