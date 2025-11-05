import { Button } from "@/components/ui/button";
import { ArrowRight, Sparkles } from "lucide-react";
import { useState } from "react";

export default function HelloWorld() {
  const [clicked, setClicked] = useState(false);
  const [consoleLog, setConsoleLog] = useState("working or not");
  console.log(consoleLog);
  const [isLoading, setIsLoading] = useState(false);
  console.log("working or not");
  const handleGetStarted = () => {
    console.log("Get Started clicked");
    setClicked(true);
    setTimeout(() => setClicked(false), 2000);
  };

  const handleLearnMore = () => {
    console.log("Learn More clicked");
  };

  return (
    <div className="relative min-h-screen w-full overflow-hidden bg-background">
      <div
        className="absolute inset-0 opacity-30"
        style={{
          background: `
            radial-gradient(circle at 20% 30%, hsl(240 68% 48% / 0.15) 0%, transparent 50%),
            radial-gradient(circle at 80% 70%, hsl(280 65% 52% / 0.12) 0%, transparent 50%),
            radial-gradient(circle at 40% 80%, hsl(200 70% 45% / 0.1) 0%, transparent 50%)
          `,
        }}
      />

      <div className="relative flex min-h-screen w-full items-center justify-center px-4 py-24 md:px-8">
        <div className="w-full max-w-6xl">
          <div className="flex flex-col items-center justify-center space-y-8 text-center">
            <div className="inline-flex items-center gap-2 rounded-full bg-primary/10 px-4 py-2 text-sm font-semibold uppercase tracking-wide text-primary">
              <Sparkles className="h-4 w-4" />
              <span data-testid="text-badge">New Experience</span>
            </div>

            <h1
              className="text-5xl font-black leading-none tracking-tight text-foreground md:text-7xl"
              data-testid="text-heading"
            >
              Hello World Updated 2
            </h1>

            <p
              className="max-w-2xl text-lg leading-relaxed text-muted-foreground md:text-xl"
              data-testid="text-subheading"
            >
              Welcome to your new web experience. A beautifully crafted space
              where modern design meets functionality.
            </p>

            <div className="flex flex-col gap-4 sm:flex-row">
              <Button
                size="lg"
                className="gap-2"
                onClick={handleGetStarted}
                data-testid="button-get-started"
              >
                {clicked ? "Welcome!" : "Get Started"}
                <ArrowRight className="h-4 w-4" />
              </Button>

              <Button
                size="lg"
                variant="outline"
                onClick={handleLearnMore}
                data-testid="button-learn-more"
              >
                Learn More
              </Button>
            </div>

            <div className="pt-16">
              <p
                className="text-sm uppercase tracking-wide text-muted-foreground/60"
                data-testid="text-footer"
              >
                Built with modern web technologies
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
