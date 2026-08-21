import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import DesktopShell from './messaging-shell';

const root = document.querySelector<HTMLDivElement>('#root');
if (!root) {
  throw new Error('Fabushi desktop root element is missing');
}

createRoot(root).render(
  <StrictMode>
    <DesktopShell />
  </StrictMode>,
);
