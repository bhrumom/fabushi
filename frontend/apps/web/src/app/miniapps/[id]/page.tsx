import McpPluginApp from "./McpPluginApp";
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
  ];
}

export default async function MiniAppPage({ params }: MiniAppPageProps) {
  const { id } = await params;

  return <McpPluginApp pluginId={id} />;
}
