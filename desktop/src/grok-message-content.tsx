import type { ReactNode } from 'react';
import styles from './messaging-shell.module.css';

function inlineContent(text: string): ReactNode[] {
  const tokens = text.split(/(`[^`]+`|\*\*[^*]+\*\*)/g).filter(Boolean);
  return tokens.map((token, index) => {
    if (token.startsWith('`') && token.endsWith('`')) return <code key={index}>{token.slice(1, -1)}</code>;
    if (token.startsWith('**') && token.endsWith('**')) return <strong key={index}>{token.slice(2, -2)}</strong>;
    return token;
  });
}

export function GrokMessageContent({ text, streaming = false }: { text: string; streaming?: boolean }) {
  const lines = text.replace(/\r\n/g, '\n').split('\n');
  const nodes: ReactNode[] = [];
  let index = 0;

  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) { index += 1; continue; }

    if (line.startsWith('```')) {
      const language = line.slice(3).trim();
      const code: string[] = [];
      index += 1;
      while (index < lines.length && !lines[index].startsWith('```')) code.push(lines[index++]);
      if (index < lines.length) index += 1;
      nodes.push(<pre key={`code-${index}`} data-language={language || undefined}><code>{code.join('\n')}</code></pre>);
      continue;
    }

    const heading = line.match(/^(#{1,3})\s+(.+)$/);
    if (heading) {
      const content = inlineContent(heading[2]);
      const key = `heading-${index}`;
      nodes.push(heading[1].length === 1 ? <h1 key={key}>{content}</h1> : heading[1].length === 2 ? <h2 key={key}>{content}</h2> : <h3 key={key}>{content}</h3>);
      index += 1;
      continue;
    }

    if (/^[-*]\s+/.test(line)) {
      const items: string[] = [];
      while (index < lines.length && /^[-*]\s+/.test(lines[index])) items.push(lines[index++].replace(/^[-*]\s+/, ''));
      nodes.push(<ul key={`ul-${index}`}>{items.map((item, itemIndex) => <li key={itemIndex}>{inlineContent(item)}</li>)}</ul>);
      continue;
    }

    if (/^\d+\.\s+/.test(line)) {
      const items: string[] = [];
      while (index < lines.length && /^\d+\.\s+/.test(lines[index])) items.push(lines[index++].replace(/^\d+\.\s+/, ''));
      nodes.push(<ol key={`ol-${index}`}>{items.map((item, itemIndex) => <li key={itemIndex}>{inlineContent(item)}</li>)}</ol>);
      continue;
    }

    if (/^>\s?/.test(line)) {
      const quote: string[] = [];
      while (index < lines.length && /^>\s?/.test(lines[index])) quote.push(lines[index++].replace(/^>\s?/, ''));
      nodes.push(<blockquote key={`quote-${index}`}>{inlineContent(quote.join(' '))}</blockquote>);
      continue;
    }

    const paragraph: string[] = [line];
    index += 1;
    while (index < lines.length && lines[index].trim() && !/^(#{1,3})\s+|^```|^[-*]\s+|^\d+\.\s+|^>\s?/.test(lines[index])) paragraph.push(lines[index++]);
    nodes.push(<p key={`p-${index}`}>{inlineContent(paragraph.join('\n'))}</p>);
  }

  return <div className={styles.assistantContent}>{nodes}{streaming ? <span className={styles.streamingCursor} aria-label="正在回复" /> : null}</div>;
}
