import { CityHeader } from "@/features/routing/(components)/CityHeader";

export default async function CityRoutingLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ cityUid: string }>;
}) {
  const { cityUid } = await params;

  return (
    <div className="space-y-6">
      <CityHeader cityUid={cityUid} />
      {children}
    </div>
  );
}
