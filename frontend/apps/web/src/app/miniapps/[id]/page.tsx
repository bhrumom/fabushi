import McpPluginApp from "./McpPluginApp";
import WebMcpMiniAppAdapter from "./WebMcpMiniAppAdapter";
import "./miniapps.css";

type MiniAppPageProps = {
  params: Promise<{ id: string }>;
};

export async function generateStaticParams() {
  return [
    { id: "global-dharma" },
    { id: "faliu-flashcards" },
    { id: "hermes-installer" },
    { id: "platform-publish" },
    { id: "bot-father" },
    { id: "mahayana-assistant" },
    { id: "chatgpt-auto-confirm" },
    { id: "computer-cleaner" },
  ];
}

export default async function MiniAppPage({ params }: MiniAppPageProps) {
  const { id } = await params;

  return (
    <>
      <WebMcpMiniAppAdapter pluginId={id} />
      <McpPluginApp pluginId={id} />
    </>
  );
}
