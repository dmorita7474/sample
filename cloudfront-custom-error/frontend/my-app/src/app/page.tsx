"use client";

import { useState, useEffect } from "react";

export default function Home() {
  const [response, setResponse] = useState<string>("");

  const handleSubmit = async () => {
    // Simulate response - replace with actual API call if needed
    try {
      const responseHello = await fetch("/api/hello")
      const result = await responseHello.json()
      setResponse(result["message"])
    } catch(e: any) {
      setResponse(e.message)
    }
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-background to-secondary p-6">
      <div className="max-w-3xl mx-auto space-y-8">
          <button
            className="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:ring-blue-300 font-medium rounded-lg text-sm px-5 py-2.5 me-2 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 focus:outline-none dark:focus:ring-blue-800"
            onClick={handleSubmit}
          >
            Submit
            </button>

        {/* Response Display Area */}
        <text className="p-6 transition-all">
          <h2 className="text-xl font-semibold mb-4">Response Area</h2>
          <div className="min-h-[100px] rounded-lg bg-muted/50 p-4">
            {response ? (
              <p className="text-foreground">{response}</p>
            ) : (
              <p className="text-muted-foreground italic">
                Response will appear here...
              </p>
            )}
          </div>
        </text>
        </div>
    </main>
  );
}