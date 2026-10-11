import { config } from "@repo/eslint-config/base";
import globals from "globals";

export default [
  ...config,
  {
    languageOptions: { globals: globals.node },
  },
];
