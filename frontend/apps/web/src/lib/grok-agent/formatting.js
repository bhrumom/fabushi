/**
 * Directly reused from Grok Bot 0.16.0:
 * packages/agent/dist/tools/core/formatting.js
 */
export function addLineNumbers(formattingOptions, code, startLineNumber) {
    if (formattingOptions.gpt5CodexCatN === true) {
        return addLineNumbersGpt5CodexCatN(code, startLineNumber);
    }
    else if (formattingOptions.gpt5StyleLineNumbers === true) {
        return addLineNumbersGpt5(code, startLineNumber);
    }
    else {
        return addLineNumbersDefault(code, startLineNumber, formattingOptions.sparseLineNumbers);
    }
}
function addLineNumbersGpt5CodexCatN(code, startLineNumber) {
    if (typeof code === "string") {
        const lines = code.split("\n");
        return lines
            .map((line, index) => {
            const lineNumber = startLineNumber + index;
            const paddedLineNumber = lineNumber.toString().padStart(6, " ");
            return `${paddedLineNumber}  ${line}`;
        })
            .join("\n");
    }
    else {
        return code
            .map(line => {
            if (Number.isInteger(line.lineNumber)) {
                const paddedLineNumber = line.lineNumber.toString().padStart(6, " ");
                return `${paddedLineNumber}  ${line.text}`;
            }
            else {
                return `...`.padStart(6, " ");
            }
        })
            .join("\n");
    }
}
function addLineNumbersDefault(code, startLineNumber, sparseN) {
    if (typeof code === "string") {
        const lines = code.split("\n");
        return lines
            .map((line, index) => {
            const lineNumber = startLineNumber + index;
            if (sparseN !== undefined && lineNumber % sparseN !== 0) {
                return line;
            }
            const paddedLineNumber = lineNumber.toString().padStart(6, " ");
            return `${paddedLineNumber}|${line}`;
        })
            .join("\n");
    }
    else {
        return code
            .map(line => {
            if (Number.isInteger(line.lineNumber)) {
                if (sparseN !== undefined && line.lineNumber % sparseN !== 0) {
                    return line.text;
                }
                const paddedLineNumber = line.lineNumber.toString().padStart(6, " ");
                return `${paddedLineNumber}|${line.text}`;
            }
            else {
                return `...`.padStart(6, " ");
            }
        })
            .join("\n");
    }
}
function addLineNumbersGpt5(code, startLineNumber) {
    if (typeof code === "string") {
        const lines = code.split("\n");
        return lines
            .map((line, index) => {
            const lineNumber = startLineNumber + index;
            return `L${lineNumber}:${line}`;
        })
            .join("\n");
    }
    else {
        return code
            .map(line => {
            if (Number.isInteger(line.lineNumber)) {
                return `L${line.lineNumber}:${line.text}`;
            }
            else {
                return "...";
            }
        })
            .join("\n");
    }
}
