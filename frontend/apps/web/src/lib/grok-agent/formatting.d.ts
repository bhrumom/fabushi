export interface DetailedLine { lineNumber: number; text: string }
export interface LineNumberOptions {
  enableLineNumbers?: boolean;
  gpt5CodexCatN?: boolean;
  gpt5StyleLineNumbers?: boolean;
  sparseLineNumbers?: number;
}
export function addLineNumbers(
  formattingOptions: LineNumberOptions,
  code: string | DetailedLine[],
  startLineNumber: number,
): string;
