// Minimal HTTP server so the API can run in a Docker container
// (Modulo 5, Tarea 2). Only answers /ping; the real backend still runs
// as Firebase Cloud Functions (see src/index.ts).

const http = require("http");

const port = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === "/ping") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("pong");
  } else {
    res.writeHead(404);
    res.end();
  }
});

// 0.0.0.0, not localhost: inside a container, localhost only accepts
// connections from inside that same container.
server.listen(port, "0.0.0.0", () => {
  console.log(`Listening on port ${port}`);
});
