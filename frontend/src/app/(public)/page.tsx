import Link from "next/link";

export default function LandingPage() {
  return (
    <div>
      {/* Hero Section */}
      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="text-4xl font-bold tracking-tight text-foreground sm:text-5xl">
          Smart Commute for
          <span className="text-brand-600"> Modern Teams</span>
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-lg text-muted-foreground">
          Find shuttle routes, compare schedules, and book your seat in seconds.
          Office commuting, simplified.
        </p>
        <div className="mt-8 flex justify-center gap-4">
          <Link
            href="/schedules"
            className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-4 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
          >
            Browse Schedules
          </Link>
          <Link
            href="/register"
            className="inline-flex h-9 items-center justify-center rounded-lg border border-border bg-background px-4 text-sm font-medium hover:bg-muted transition-colors"
          >
            Get Started
          </Link>
        </div>
      </section>

      {/* How it works */}
      <section className="border-t bg-secondary py-16">
        <div className="container mx-auto px-4">
          <h2 className="text-center text-2xl font-bold text-foreground">
            How it works
          </h2>
          <div className="mt-10 grid gap-8 sm:grid-cols-3">
            {[
              {
                step: "1",
                title: "Search",
                description: "Find shuttles by route, date, or company",
              },
              {
                step: "2",
                title: "Book",
                description: "Select your seat and confirm in one tap",
              },
              {
                step: "3",
                title: "Ride",
                description: "Show up and enjoy your commute",
              },
            ].map((item) => (
              <div key={item.step} className="text-center">
                <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-brand-100 text-lg font-bold text-brand-700">
                  {item.step}
                </div>
                <h3 className="mt-4 font-semibold text-foreground">{item.title}</h3>
                <p className="mt-2 text-sm text-muted-foreground">{item.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
}
