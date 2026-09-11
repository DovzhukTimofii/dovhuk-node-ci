const http = require("http");
const { Client } = require("pg");

const port = process.env.PORT || 3000;
const databaseUrl = process.env.DATABASE_URL;

async function checkDatabase() {
  if (!databaseUrl) {
    console.log("DATABASE_URL is not set. Starting without PostgreSQL connection check.");
    return;
  }

  const client = new Client({ connectionString: databaseUrl });

  try {
    await client.connect();
    const result = await client.query("SELECT NOW() AS now");
    console.log("PostgreSQL connection successful:", result.rows[0].now);
  } catch (error) {
    console.error("PostgreSQL connection failed:", error.message);
  } finally {
    await client.end().catch(() => {});
  }
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Docker CI/CD Node.js application is running!\n");
});

server.listen(port, "0.0.0.0", async () => {
  console.log(`Server is running on port ${port}`);
  await checkDatabase();
});
