const express = require("express");

const app = express();
const PORT = 3000;

app.get("/", (req, res) => {
  res.send("<h1>Aryen Mukundam 10198</h1>");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});