import { notFound } from "next/navigation";
import BotFatherCommercePanel from "./BotFatherCommercePanel";
import DeveloperPayoutPanel from "./DeveloperPayoutPanel";
import PayoutOnboardingCard from "./PayoutOnboardingCard";

type CommercePageProps = { params: Promise<{ id: string }> };

export function generateStaticParams() {
  return [{ id: "bot-father" }];
}

export default async function CommercePage({ params }: CommercePageProps) {
  const { id } = await params;
  if (id !== "bot-father") notFound();
  return (
    <>
      <BotFatherCommercePanel />
      <main style={{ maxWidth: 1080, margin: "-46px auto 0", padding: "0 24px 64px" }}>
        <DeveloperPayoutPanel />
        <PayoutOnboardingCard />
      </main>
    </>
  );
}
