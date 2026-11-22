import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**.shuttle.app",
      },
    ],
  },
  async rewrites() {
    // fallback: the proxy to Rails applies only after the app's own route handlers, dynamic ones
    // included (e.g. /api/reservations/[uid]/payment). A plain array would run before dynamic
    // routes and send those requests straight to Rails, where they do not exist.
    return {
      beforeFiles: [],
      afterFiles: [],
      fallback: [
        {
          source: "/api/:path*",
          destination: `${process.env.INTERNAL_API_URL || "http://localhost:3000"}/api/:path*`,
        },
      ],
    };
  },
};

export default nextConfig;
