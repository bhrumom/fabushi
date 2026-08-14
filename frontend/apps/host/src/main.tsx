import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import HostClient from "../../web/src/app/host/host-client";

const root = document.querySelector<HTMLDivElement>("#root");
if (!root) {
  throw new Error("Fabushi Host root element is missing");
}

createRoot(root).render(
  <StrictMode>
    <HostClient />
  </StrictMode>,
);
