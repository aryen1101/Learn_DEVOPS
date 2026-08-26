const express = require("express");

const app = express();

app.get("/", (req, res) => {
    res.send("<h1>Hello World from Node.js!</h1>");
});

app.listen(8080, "0.0.0.0", () => {
    console.log("Node.js server running on port 8080");
});