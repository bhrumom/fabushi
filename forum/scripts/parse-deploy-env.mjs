export function decodeDoubleQuotedValue(value) {
  let decoded = "";

  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];

    if (character !== "\\") {
      decoded += character;
      continue;
    }

    const nextCharacter = value[index + 1];
    if (nextCharacter === undefined) {
      decoded += "\\";
      continue;
    }

    const escapeMap = {
      "\\": "\\",
      '"': '"',
      "'": "'",
      n: "\n",
      r: "\r",
      t: "\t",
    };

    decoded += escapeMap[nextCharacter] ?? nextCharacter;
    index += 1;
  }

  return decoded;
}

export function decodeSingleQuotedValue(value) {
  let decoded = "";

  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];

    if (character !== "\\") {
      decoded += character;
      continue;
    }

    const nextCharacter = value[index + 1];
    if (nextCharacter === undefined) {
      decoded += "\\";
      continue;
    }

    if (nextCharacter === "'" || nextCharacter === "\\") {
      decoded += nextCharacter;
      index += 1;
      continue;
    }

    decoded += character;
  }

  return decoded;
}

export function stripInlineComment(rawValue) {
  let quoteCharacter = null;
  let escaped = false;

  for (let index = 0; index < rawValue.length; index += 1) {
    const character = rawValue[index];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (quoteCharacter) {
      if (character === "\\") {
        escaped = true;
        continue;
      }

      if (character === quoteCharacter) {
        quoteCharacter = null;
      }

      continue;
    }

    if (character === '"' || character === "'") {
      quoteCharacter = character;
      continue;
    }

    if (character === "#" && (index === 0 || /\s/.test(rawValue[index - 1]))) {
      return rawValue.slice(0, index).trimEnd();
    }
  }

  return rawValue.trimEnd();
}

export function parseComposeEnvValue(rawValue) {
  const valueWithoutComment = stripInlineComment(rawValue.trim());

  if (valueWithoutComment.length < 2) {
    return valueWithoutComment;
  }

  const quoteCharacter = valueWithoutComment[0];
  if ((quoteCharacter !== '"' && quoteCharacter !== "'") || valueWithoutComment.at(-1) !== quoteCharacter) {
    return valueWithoutComment;
  }

  const innerValue = valueWithoutComment.slice(1, -1);
  return quoteCharacter === '"' ? decodeDoubleQuotedValue(innerValue) : decodeSingleQuotedValue(innerValue);
}

export function parseDotEnv(content) {
  const values = {};

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();

    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = rawLine.search(/[=:]/);
    if (separatorIndex === -1) {
      throw new Error(`Expected KEY=VALUE line in deploy env file, received: ${rawLine}`);
    }

    const key = rawLine.slice(0, separatorIndex).trim();
    const value = rawLine.slice(separatorIndex + 1);
    values[key] = parseComposeEnvValue(value);
  }

  return values;
}
