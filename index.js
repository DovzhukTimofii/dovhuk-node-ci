const http = require("http");

const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("CI/CD deployment works!\n");
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Server is running on port ${port}`);
});
