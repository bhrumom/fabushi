import { notFound } from "next/navigation";
import BotFatherCommercePanel from "./BotFatherCommercePanel";

type CommercePageProps = { params: Promise<{ id: string }> };

export default async function CommercePage({ params }: CommercePageProps) {
  const { id } = await params;
  if (id !== "bot-father") notFound();
  return <BotFatherCommercePanel />;
}
